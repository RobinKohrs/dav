# Ensure this is saved in e.g., R/geosphere_explore_resource.R

#' Explore Geosphere Resource Metadata and Requirements
#'
#' @description
#' Fetches metadata and determines required query parameters for a specific
#' Geosphere resource ID across all its available type, mode, and format
#' combinations. It presents available parameters, coverage details, and the
#' definitive required parameters needed to query the data endpoint via
#' `geosphere_get_data`.
#'
#' @details
#' This function first retrieves descriptive metadata (available parameters, time range, etc.)
#' from the resource's `/metadata` endpoint. Then, for each combination, it makes a
#' deliberate (parameter-less) request to the main *data* endpoint to provoke an
#' error message. By parsing this error message (typically JSON with a 'detail'
#' field), it accurately identifies the query parameters that the API requires
#' for that specific data endpoint.
#'
#' @param resource_id Character string. The specific dataset or resource ID. Required.
#' @param api_url Base URL for the Geosphere API. Defaults to Geosphere Hub v1.
#' @param version API version string. Defaults to "v1".
#' @param user_agent A string to identify the client. Defaults to "davR".
#' @param print_summary Logical. If `TRUE` (default), print a formatted summary
#'   to the console for each combination found.
#'
#' @return A named list where each element corresponds to a unique combination of
#'   `type`, `mode`, and `response_formats` found for the `resource_id`. The name
#'   of each element is a descriptive string like `"station_historical_csv"`.
#'   Each element is itself a list containing:
#'   \item{combination}{A list detailing the specific type, mode, and formats.}
#'   \item{metadata}{The full raw metadata list fetched from the API's `/metadata` endpoint (or NULL if failed).}
#'   \item{available_parameters}{A data frame (tibble) of available parameters (if found in metadata).}
#'   \item{time_coverage}{A list indicating start/end times (if found in metadata).}
#'   \item{spatial_info}{A list with spatial details (CRS, bbox, etc.) (if found in metadata).}
#'   \item{required_query_params}{A character vector listing the query parameters identified as required by probing the data endpoint (or NULL if determination failed).}
#'   Returns `NULL` if the initial dataset lookup fails or the `resource_id` is not found.
#'
#' @export geosphere_explore_resource
#'
#' @importFrom httr GET modify_url content http_type status_code user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_h1 cli_h2 cli_li cli_ul cli_text cli_alert_danger cli_alert_warning cli_alert_info cli_code style_hyperlink cli_end
#' @importFrom utils head str
#' @importFrom dplyr distinct select pick filter any_of all_of mutate bind_rows
#' @importFrom glue glue
#' @importFrom tibble as_tibble
#'
#' @examples
#' \dontrun{
#' # Assume geosphere_find_datasets is available
#'
#' # Explore a resource known to have multiple combinations
#' exploration_results = geosphere_explore_resource(
#'    resource_id = "apolis_short-v1-1d-100m"
#' )
#'
#' # The function prints summaries by default.
#' # The returned object is a list named by combinations:
#' print(names(exploration_results))
#' # > [1] "grid_historical_geojson"     "grid_historical_netcdf" ...
#'
#' # Inspect the details for one specific combination:
#' if ("grid_historical_geojson" %in% names(exploration_results)) {
#'    # Check the *required* parameters found by probing the data endpoint:
#'    print(exploration_results$grid_historical_geojson$required_query_params)
#'    # Should show: [1] "parameters" "start" "end" "bbox" (based on the example error)
#'
#'    # Compare with *available* parameters from metadata:
#'    print(utils::head(exploration_results$grid_historical_geojson$available_parameters))
#' }
#'
#' # Explore a resource with likely only one combination
#' exploration_klima = geosphere_explore_resource(resource_id = "klima-v2-1h")
#' if (!is.null(exploration_klima)) {
#'    print(names(exploration_klima))
#'    # Likely "station_historical_csv" or similar
#'    print(exploration_klima[[1]]$required_query_params)
#'    # Should show something like "parameters", "start", "end", "station_ids"
#' }
#' }
geosphere_explore_resource = function(resource_id,
                                      api_url = "https://dataset.api.hub.geosphere.at",
                                      version = "v1",
                                      user_agent = "davR",
                                      print_summary = TRUE) {

  # --- 1. Input Validation ---
  if (missing(resource_id) || !is.character(resource_id) || length(resource_id) != 1 || nchar(trimws(resource_id)) == 0) {
    stop("`resource_id` is required and must be a non-empty string.", call. = FALSE)
  }
  resource_id = trimws(resource_id)

  # --- 2. Find all dataset entries for the resource_id ---
  cli::cli_alert_info("Looking up all combinations for resource ID: {.val {resource_id}}")

  # Ensure geosphere_find_datasets exists
  if (!exists("geosphere_find_datasets", mode = "function")) {
    stop("Dependency function 'geosphere_find_datasets' not found.", call. = FALSE)
  }

  all_datasets = tryCatch(
    geosphere_find_datasets(add_resource_id = TRUE, user_agent = user_agent),
    error = function(e){
      cli::cli_alert_danger("Failed to retrieve dataset list.")
      cli::cli_alert_danger("Error: {e$message}")
      return(NULL)
    }
  )
  if (is.null(all_datasets)) return(NULL)

  # Filter for the specific resource ID
  matching_datasets = dplyr::filter(all_datasets, .data$resource_id == !!resource_id)

  if (nrow(matching_datasets) == 0) {
    cli::cli_alert_danger(glue::glue("Resource ID '{resource_id}' not found in the available datasets list."))
    return(NULL)
  }

  # --- 3. Identify Unique Combinations (Type, Mode, Formats) ---
  cols_to_check = intersect(c("type", "mode", "response_formats"), names(matching_datasets))
  if (!all(c("type", "mode") %in% cols_to_check)) {
    stop("Internal error: Could not find 'type' and 'mode' columns in the dataset list.", call.=FALSE)
  }

  # Prepare for distinct check, handling list-column 'response_formats'
  if ("response_formats" %in% cols_to_check && is.list(matching_datasets$response_formats)) {
    matching_datasets = dplyr::mutate(
      matching_datasets,
      response_formats_str = sapply(.data$response_formats, function(x) {
        clean_formats = tolower(sort(unique(unlist(x))))
        paste(clean_formats, collapse="_")
      })
    )
    cols_for_distinct = c("type", "mode", "response_formats_str")
  } else if ("response_formats" %in% cols_to_check) {
    matching_datasets = dplyr::mutate(matching_datasets, response_formats_str = as.character(.data$response_formats))
    cols_for_distinct = c("type", "mode", "response_formats_str")
  } else {
    matching_datasets = dplyr::mutate(matching_datasets, response_formats_str = "unknown")
    cols_for_distinct = c("type", "mode", "response_formats_str")
  }

  unique_combinations = dplyr::distinct(matching_datasets, dplyr::pick(dplyr::all_of(cols_for_distinct)))

  n_combinations = nrow(unique_combinations)
  cli::cli_alert_info("Found {n_combinations} unique type/mode/format combination{?s} for resource ID {.val {resource_id}}.")
  if (n_combinations > 1) {
    cli::cli_alert_warning("Multiple combinations found. Details for each will be provided.")
  }

  # --- 4. Iterate, Fetch/Interpret Metadata, Probe for Required Params ---
  results_list = list()

  for (i in 1:n_combinations) {
    current_combo = unique_combinations[i, ]
    type = current_combo$type
    mode = current_combo$mode
    formats_str = current_combo$response_formats_str # Use the standardized string
    list_name = paste(type, mode, formats_str, sep = "_")
    list_name = gsub("[^a-zA-Z0-9_]", "_", list_name) # Clean name

    cli::cli_h1("Processing Combination: {.val {list_name}} ({i}/{n_combinations})")

    # --- 4a. Fetch and Interpret Metadata ---
    cli::cli_alert_info("Fetching descriptive metadata...")
    # Ensure geosphere_get_resource_metadata exists
    if (!exists("geosphere_get_resource_metadata", mode = "function")) {
      stop("Dependency function 'geosphere_get_resource_metadata' not found.", call. = FALSE)
    }
    current_metadata = geosphere_get_resource_metadata(
      resource_id = resource_id, type = type, mode = mode, interactive = FALSE, # Use determined type/mode
      api_url = api_url, version = version, user_agent = user_agent
    )

    output_element = list(
      combination = list(type=type, mode=mode, formats=strsplit(formats_str, "_")[[1]]),
      metadata = NULL, # Initialize
      available_parameters = NULL, time_coverage = NULL, spatial_info = NULL,
      required_query_params = NULL # Initialize required params list
    )

    if (is.null(current_metadata)) {
      cli::cli_alert_warning("Could not fetch or parse metadata for combination {.val {list_name}}.")
      # Continue to try probing for required params, but metadata sections will be empty
    } else {
      output_element$metadata = current_metadata # Store raw metadata
      # Extract Available Parameters
      if (!is.null(current_metadata$parameters)) {
        if (is.data.frame(current_metadata$parameters)) output_element$available_parameters = tibble::as_tibble(current_metadata$parameters)
        else if (is.list(current_metadata$parameters) && length(current_metadata$parameters) > 0) {
          param_df = tryCatch(dplyr::bind_rows(current_metadata$parameters), error = function(e) NULL)
          if (!is.null(param_df)) output_element$available_parameters = tibble::as_tibble(param_df)
        }
      }
      # Extract Time Coverage
      time_info = list(); if (!is.null(current_metadata$start_time)) time_info$start_time = current_metadata$start_time; if (!is.null(current_metadata$end_time)) time_info$end_time = current_metadata$end_time; if (!is.null(current_metadata$timerange)) time_info$timerange = current_metadata$timerange; if (length(time_info) > 0) output_element$time_coverage = time_info
      # Extract Spatial Info
      spatial = list(); if (!is.null(current_metadata$crs)) spatial$crs = current_metadata$crs; if (!is.null(current_metadata$bbox)) spatial$bbox = current_metadata$bbox; if (!is.null(current_metadata$spatial_resolution_m)) spatial$resolution_m = current_metadata$spatial_resolution_m; if (!is.null(current_metadata$grid_bounds)) spatial$grid_bounds = current_metadata$grid_bounds; if (length(spatial) > 0) output_element$spatial_info = spatial
    }

    # --- 4b. Probe Data Endpoint for Required Parameters ---
    cli::cli_alert_info("Probing data endpoint to determine required parameters...")
    data_path = paste(version, type, mode, resource_id, sep = "/")
    data_url = httr::modify_url(api_url, path = data_path)
    ua = httr::user_agent(user_agent)
    required_params_found = NULL # Initialize

    probe_response = tryCatch(
      httr::GET(data_url, ua), # No query parameters intentionally
      error = function(e) {
        cli::cli_alert_danger("HTTP request failed when probing data URL {.url {data_url}}")
        cli::cli_alert_danger("Error: {e$message}")
        return(NULL) # Return NULL on connection failure
      }
    )

    if (!is.null(probe_response)) {
      status = httr::status_code(probe_response)
      # We expect a 4xx error (like 422 or 400)
      if (status >= 400 && status < 500) {
        # Try to parse the error response
        error_content = NULL
        error_text = httr::content(probe_response, as = "text", encoding = "UTF-8")
        if (nzchar(error_text)) {
          error_content = tryCatch(
            jsonlite::fromJSON(error_text, simplifyVector = TRUE),
            error = function(e) {
              cli::cli_alert_warning("Could not parse error response from data endpoint as JSON.")
              return(NULL)
            })
        }

        # Check if the parsed content has the expected structure
        if (!is.null(error_content) && is.list(error_content) && !is.null(error_content$detail) && (is.list(error_content$detail) || is.data.frame(error_content$detail))) {
          details_list = error_content$detail
          # Handle if detail is a data frame or list of lists
          if (is.data.frame(details_list)) {
            if ("loc" %in% names(details_list) && is.list(details_list$loc)) {
              # Extract second element from each 'loc' list (expected ["query", "param_name"])
              req_params = unique(sapply(details_list$loc, function(loc_item) {
                if (length(loc_item) >= 2 && loc_item[1] == "query") {
                  return(loc_item[2])
                } else { return(NA_character_) }
              }))
              required_params_found = req_params[!is.na(req_params)]
            }
          } else if (is.list(details_list)) { # Assuming list of lists
            req_params = unique(sapply(details_list, function(item) {
              if (is.list(item) && !is.null(item$loc) && length(item$loc) >= 2 && item$loc[1] == "query") {
                return(item$loc[2])
              } else { return(NA_character_) }
            }))
            required_params_found = req_params[!is.na(req_params)]
          }
        } # End if error content structure is valid

        if (is.null(required_params_found)) {
          cli::cli_alert_warning("Received HTTP {status} error, but could not extract required parameters from the response body.")
          # Maybe print the body for debugging?
          # if (nzchar(error_text)) cli::cli_text("Response body: {substr(error_text, 1, 300)}")
        } else if (length(required_params_found) == 0) {
          cli::cli_alert_info("Received HTTP {status} error, but the response indicated no specific missing query parameters.")
          # This might mean the base URL itself is valid but needs other input (e.g., POST data?) - less likely for GET
        }

      } else {
        # Request succeeded (unexpected!) or was a server error (5xx)
        cli::cli_alert_warning("Probing data endpoint did not return expected 4xx error (Status: {status}). Cannot reliably determine required parameters this way.")
        # Maybe the endpoint works without parameters? Or server issue.
      }
    } # End if !is.null(probe_response)

    output_element$required_query_params = required_params_found # Store found params or NULL


    # --- 4c. Print Summary (Optional) ---
    if (print_summary) {
      cli::cli_h2("Summary for Combination: {.val {list_name}}")
      if (!is.null(current_metadata$title)) cli::cli_text("Title: {.val {current_metadata$title}}")
      cli::cli_text("Data Query URL (Base): {.url {data_url}}")
      if (!is.null(current_metadata)) cli::cli_text("Metadata URL: {.url {paste0(data_url,'/metadata')}}")

      cli::cli_h2("Available Parameters (from Metadata)")
      if (!is.null(output_element$available_parameters) && nrow(output_element$available_parameters) > 0) {
        cols_to_print = intersect(c("name", "long_name", "unit", "desc"), names(output_element$available_parameters))
        print_df = if(length(cols_to_print) > 0) output_element$available_parameters[, cols_to_print, drop = FALSE] else output_element$available_parameters
        print(utils::head(print_df))
        if(nrow(print_df) > 6) cli::cli_text("({nrow(print_df) - 6} more parameters available...)")
      } else { cli::cli_text("No specific parameter list found in metadata.") }

      cli::cli_h2("Time Coverage (from Metadata)")
      if (!is.null(output_element$time_coverage)) {
        cli::cli_ul(); lapply(names(output_element$time_coverage), function(n) cli::cli_li("{tools::toTitleCase(gsub('_',' ',n))}: {.val {paste(output_element$time_coverage[[n]], collapse=', ')}}")); cli::cli_end()
      } else { cli::cli_text("No specific time coverage info found.") }

      cli::cli_h2("Spatial Information (from Metadata)")
      if (!is.null(output_element$spatial_info)) {
        cli::cli_ul(); lapply(names(output_element$spatial_info), function(n) { value = output_element$spatial_info[[n]]; formatted_value = if(is.numeric(value)) paste(round(value,4),collapse=', ') else paste(value,collapse=', '); cli::cli_li("{tools::toTitleCase(gsub('_',' ',n))}: {.val {formatted_value}}") }); cli::cli_end()
      } else { cli::cli_text("No specific spatial info found.") }

      cli::cli_h2("Required Query Parameters for {.fn geosphere_get_data} (determined by probing)")
      if (!is.null(output_element$required_query_params) && length(output_element$required_query_params) > 0) {
        cli::cli_ul(); for(p in output_element$required_query_params) cli::cli_li("{.code {p}}"); cli::cli_end()
      } else if (is.null(output_element$required_query_params)) {
        cli::cli_text("Could not determine required parameters (probe failed or response unparseable).")
      } else { # length is 0
        cli::cli_text("Probe suggests no specific query parameters are required (or endpoint works differently).")
      }
      if(n_combinations > 1 && i < n_combinations) cli::cli_h1("---") # Separator
    } # end if print_summary

    # Store the results for this combination
    results_list[[list_name]] = output_element

  } # end for loop over combinations

  # --- 5. Return the List of Results ---
  return(results_list)
}
