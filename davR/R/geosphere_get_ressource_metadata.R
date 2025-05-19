# Make sure to save this code in a file named e.g.,
# R/geosphere_get_resource_metadata.R

#' Get Metadata for a Geosphere Resource (with auto-lookup)
#'
#' @description
#' Retrieves the metadata for a specific Geosphere API resource. If `type` and/or
#' `mode` are not provided, the function attempts to look them up using
#' `geosphere_find_datasets`. It considers the `response_formats` when checking
#' for unique combinations and can handle ambiguity either by stopping or prompting
#' the user interactively.
#'
#' @param resource_id Character string. The specific dataset or resource ID
#'   (e.g., "apolis_short-v1-1d-100m", "klima-v2-1h"). This is required.
#' @param type Character string or `NULL`. The data type (e.g., "grid", "station").
#'   If `NULL` (default), the function will try to look it up.
#' @param mode Character string or `NULL`. The data mode (e.g., "historical").
#'   If `NULL` (default), the function will try to look it up.
#' @param interactive Logical. If `TRUE` and multiple type/mode/format combinations are
#'   found for the `resource_id`, prompt the user to select one via a menu.
#'   Defaults to `FALSE` (stops with an error in case of ambiguity).
#' @param api_url Base URL for the Geosphere API. Defaults to Geosphere Hub v1.
#' @param version API version string. Defaults to "v1".
#' @param user_agent A string to identify the client. Defaults to "davR".
#'
#' @return A list parsed from the JSON metadata response for the *selected* or
#'   *specified* type/mode combination. The list also includes `$determined_type`
#'   and `$determined_mode` indicating which combination was used. Returns `NULL`
#'   if the request fails, the resource ID is not found, or the user cancels
#'   interactive selection.
#'
#' @export geosphere_get_resource_metadata
#'
#' @importFrom httr GET modify_url stop_for_status content http_type user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_alert_danger cli_alert_info cli_text
#' @importFrom utils menu head
#' @importFrom dplyr distinct select pick filter any_of all_of mutate
#' @importFrom glue glue
#'
#' @examples
#' \dontrun{
#' # Assume geosphere_find_datasets is available in the package or environment
#'
#' # Example 1: Interactive lookup for a resource with multiple formats
#' try({
#'   meta_interactive = geosphere_get_resource_metadata(
#'      resource_id = "apolis_short-v1-1d-100m",
#'      interactive = TRUE
#'   )
#'   # You might be prompted to choose between grid/geojson, grid/netcdf, etc.
#'   if (!is.null(meta_interactive)) {
#'      print(paste("Metadata fetched for type:", meta_interactive$determined_type,
#'                  "mode:", meta_interactive$determined_mode))
#'      print(names(meta_interactive))
#'   }
#' })
#'
#' # Example 2: Explicitly provide type and mode (lookup is skipped)
#' try({
#'   meta_explicit = geosphere_get_resource_metadata(
#'      resource_id = "klima-v2-1h",
#'      type = "station",
#'      mode = "historical"
#'   )
#'   if (!is.null(meta_explicit)) {
#'      print(utils::head(meta_explicit$parameters)) # Use utils::head explicitly
#'   }
#' })
#'
#' # Example 3: Provide only resource_id, non-interactive (will likely error if ambiguous)
#' # try(geosphere_get_resource_metadata(resource_id = "apolis_short-v1-1d-100m"))
#'
#' }
geosphere_get_resource_metadata = function(resource_id,
                                           type = NULL,
                                           mode = NULL,
                                           interactive = FALSE,
                                           api_url = "https://dataset.api.hub.geosphere.at",
                                           version = "v1",
                                           user_agent = "davR") {

  # --- 1. Input Validation ---
  if (missing(resource_id) || !is.character(resource_id) || length(resource_id) != 1 || nchar(trimws(resource_id)) == 0) {
    stop("`resource_id` is required and must be a non-empty string.", call. = FALSE)
  }
  resource_id = trimws(resource_id)
  original_type = type
  original_mode = mode

  # --- 2. Lookup Type/Mode if Necessary ---
  if (is.null(original_type) || is.null(original_mode)) {
    cli::cli_alert_info("`type` or `mode` not specified. Looking up resource ID: {.val {resource_id}}")

    # Ensure geosphere_find_datasets exists in the package's namespace or global env
    if (!exists("geosphere_find_datasets", mode = "function")) {
      stop("Helper function 'geosphere_find_datasets' not found. Cannot perform lookup.", call. = FALSE)
    }

    # Call find_datasets
    all_datasets = tryCatch(
      geosphere_find_datasets(add_resource_id = TRUE, user_agent = user_agent),
      error = function(e){
        cli::cli_alert_danger("Failed to retrieve dataset list to lookup type/mode.")
        cli::cli_alert_danger("Error: {e$message}")
        return(NULL)
      }
    )

    if (is.null(all_datasets)) return(NULL)

    # Filter for the specific resource ID
    matching_datasets = dplyr::filter(all_datasets, .data$resource_id == !!resource_id)

    if (nrow(matching_datasets) == 0) {
      stop(glue::glue("Resource ID '{resource_id}' not found in the available datasets list."), call. = FALSE)
    }

    # Get unique combinations of type, mode, and response_formats for this resource_id
    cols_to_check = intersect(c("type", "mode", "response_formats"), names(matching_datasets))
    if (!all(c("type", "mode") %in% cols_to_check)) {
      stop("Could not find 'type' and 'mode' columns in the dataset list for lookup.", call.=FALSE)
    }

    # Handle potential list column for response_formats
    if ("response_formats" %in% names(matching_datasets) && is.list(matching_datasets$response_formats)) {
      matching_datasets = dplyr::mutate(
        matching_datasets,
        response_formats_str = sapply(.data$response_formats, function(x) paste(sort(unlist(x)), collapse=","))
      )
      cols_for_distinct = c("type", "mode", "response_formats_str")
    } else if ("response_formats" %in% names(matching_datasets)) {
      cols_for_distinct = c("type", "mode", "response_formats")
    } else {
      cols_for_distinct = c("type", "mode")
    }

    # Get distinct combinations based on available columns
    unique_combinations = dplyr::distinct(matching_datasets, dplyr::pick(dplyr::all_of(cols_for_distinct)))


    # --- Disambiguation Logic ---
    if (nrow(unique_combinations) == 1) {
      # Only one unique combination found - use it
      type = unique_combinations$type[1]
      mode = unique_combinations$mode[1]
      format_info = if ("response_formats" %in% cols_for_distinct) unique_combinations[[cols_for_distinct[cols_for_distinct=="response_formats"]]][1] else if ("response_formats_str" %in% cols_for_distinct) unique_combinations[[cols_for_distinct[cols_for_distinct=="response_formats_str"]]][1] else "N/A"
      cli::cli_alert_info("Found unique combination: type={.val {type}}, mode={.val {mode}}, formats={.val {format_info}}.")

    } else {
      # Multiple combinations found
      cli::cli_text("Multiple type/mode/format combinations found for resource ID {.val {resource_id}}:")

      # Prepare choices for display/menu, including formats
      choice_labels = apply(unique_combinations, 1, function(row) {
        type_val = row["type"]
        mode_val = row["mode"]
        format_val = if ("response_formats" %in% names(row)) row["response_formats"] else if ("response_formats_str" %in% names(row)) row["response_formats_str"] else "N/A"
        paste0("type='", type_val, "', mode='", mode_val, "', formats='", format_val, "'")
      })

      if (interactive && base::interactive()) { # Check if session is interactive
        # Present menu to user
        cli::cli_text("Please select the desired combination:")
        selection = utils::menu(choices = choice_labels, title = "Select type/mode/format:")

        if (selection == 0) {
          cli::cli_alert_danger("User canceled selection. Aborting.")
          return(NULL) # User canceled
        } else {
          # User selected one - extract type and mode
          selected_row = unique_combinations[selection, ]
          type = selected_row$type
          mode = selected_row$mode
          selected_format = if ("response_formats" %in% names(selected_row)) selected_row$response_formats else if ("response_formats_str" %in% names(selected_row)) selected_row$response_formats_str else "N/A"
          cli::cli_alert_info("User selected combination yielding: type={.val {type}}, mode={.val {mode}} (formats={.val {selected_format}}).")
        }
      } else {
        # Not interactive or session not interactive - stop with error
        cli::cli_text("Please specify the desired 'type' and 'mode' explicitly.")
        if (!interactive) cli::cli_text("Alternatively, run with `interactive = TRUE` in an interactive R session.")
        stop(paste("Ambiguous resource ID. Found combinations:", paste(choice_labels, collapse = "; ")), call. = FALSE)
      }
    }
    # 'type' and 'mode' should be set if successful
  } else {
    # Type and mode were provided by the user
    type = trimws(type)
    mode = trimws(mode)
    # Optional: add verbose message here if desired
    # if (verbose) cli::cli_alert_info("Using provided type={.val {type}} and mode={.val {mode}}.")
  }

  # --- 3. Construct Metadata URL ---
  if (is.null(type) || is.null(mode) || !nzchar(type) || !nzchar(mode)) {
    # This condition should ideally not be reached due to prior checks/stops
    stop("Internal error: Could not determine 'type' and 'mode' for the resource.", call. = FALSE)
  }
  metadata_path = paste(version, type, mode, resource_id, "metadata", sep = "/")
  metadata_url = httr::modify_url(api_url, path = metadata_path)

  # --- 4. Perform HTTP GET Request ---
  ua = httr::user_agent(user_agent)
  response = tryCatch(
    httr::GET(metadata_url, ua),
    error = function(e) {
      cli::cli_alert_danger("HTTP request failed for metadata URL {.url {metadata_url}}")
      cli::cli_alert_danger("Error: {e$message}")
      return(NULL)
    }
  )

  if (is.null(response)) return(NULL)

  # --- 5. Check HTTP Status & Parse ---
  metadata_content = NULL
  error_occurred = FALSE

  tryCatch(
    {
      # Check for HTTP client/server errors (4xx, 5xx)
      httr::stop_for_status(response, task = paste("fetch metadata for", resource_id, "(type=", type, ", mode=", mode, ")"))

      # Check content type (optional but good practice)
      if (!grepl("application/json", httr::http_type(response), ignore.case = TRUE)) {
        warning("API did not return JSON content as expected for metadata. Content type was: ",
                httr::http_type(response), ". Attempting parse.", call. = FALSE)
      }

      # Parse JSON response
      response_text = httr::content(response, as = "text", encoding = "UTF-8")
      if (!nzchar(response_text)) {
        stop("Received empty response body from metadata endpoint.", call. = FALSE)
      }
      metadata_content = jsonlite::fromJSON(response_text, simplifyVector = TRUE)

    },
    # --- Error Handling within tryCatch ---
    http_error = function(e) {
      error_occurred <<- TRUE # Assign to flag in parent scope
      cli::cli_alert_danger("Failed to fetch metadata for resource '{resource_id}' (type='{type}', mode='{mode}')")
      err_msg = conditionMessage(e)
      # Try extracting status code
      status_match = regexpr("\\b\\d{3}\\b", err_msg)
      if (attr(status_match, "match.length") > 0) {
        status = regmatches(err_msg, status_match)
        cli::cli_alert_danger("HTTP Status: {status}")
      } else {
        cli::cli_alert_danger("HTTP Error (check URL and resource details)")
      }
      # Try showing part of the response body
      resp_body = NULL
      if (!is.null(e$response) && !is.null(e$response$content) && length(e$response$content) > 0) {
        resp_body = tryCatch(rawToChar(e$response$content), error=function(e2) NULL)
      }
      if (!is.null(resp_body)) {
        cleaned_body = gsub('[[:cntrl:]]',' ', resp_body) # Clean control chars
        cli::cli_alert_danger("API Response (partial): {substr(cleaned_body, 1, 200)}")
      }

    },
    error = function(e) {
      error_occurred <<- TRUE # Assign to flag in parent scope
      cli::cli_alert_danger("Failed to process metadata response for resource '{resource_id}' (type='{type}', mode='{mode}')")
      cli::cli_alert_danger("Error: {e$message}")
    }
  ) # End tryCatch

  # --- 6. Return Result ---
  if (error_occurred) {
    return(NULL)
  } else {
    # Add determined type/mode back into the returned list for context
    if (is.list(metadata_content)) {
      metadata_content$determined_type = type
      metadata_content$determined_mode = mode
    }
    return(metadata_content)
  }
}
