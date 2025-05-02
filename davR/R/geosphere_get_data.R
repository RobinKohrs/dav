#' Get data from Geosphere Austria's Open Data Hub
#'
#' @description
#' Constructs a URL and fetches data from the Geosphere API's main resource endpoint
#' based on the provided parameters. The function allows fetching data as a file
#' path (default), directly into an R object (data frame), or as the raw HTTP response.
#'
#' **Note:** This function retrieves data from the primary resource path (e.g.,
#' `/v1/timeseries/historical/{resource_id}`). To retrieve metadata (usually found
#' at `/metadata` appended to the resource path), you would need to construct the
#' URL manually and use a tool like `httr::GET`.
#'
#' See the Geosphere API documentation for details on available endpoints and parameters:
#' \itemize{
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/docs/getting-started.html}{Getting Started}
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/docs/user-guide/resource.html#resources}{Resources}
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/datasets}{Datasets Overview}
#' }
#' Example endpoint: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km}{SPARTACUS Monthly}
#' Example metadata URL: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km/metadata}{SPARTACUS Monthly Metadata}
#'
#' @param resource_id **Required.** The specific dataset or resource ID (e.g., "klima-v2-1m"). Cannot be NULL or empty.
#' @param parameters Character vector or comma-separated string of parameter IDs to retrieve (e.g., `c("tl", "tx")`, `"tl,tx"`). Check API metadata for available parameters.
#' @param start Start date/time string (ISO 8601 format preferred, e.g., "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS").
#' @param end End date/time string (ISO 8601 format preferred).
#' @param station_ids Character vector or comma-separated string of station IDs (e.g., `c("5925", "11035")`, `"5925,11035"`). Check API metadata for available stations.
#' @param output_format The desired data format from the API (e.g., "csv", "json", "geojson"). Defaults to "csv". Passed as a query parameter.
#' @param ... Additional query parameters specific to the API endpoint. Values will be automatically URL-encoded. Use this for less common parameters not covered by explicit arguments.
#' @param api_url Base URL for the Geosphere API.
#' @param version API version string or number (e.g., "v1", "2", 1). Defaults to "v1". Will be formatted as "vX" in the URL path.
#' @param type Data type (e.g., "timeseries", "station", "grid").
#' @param mode Data mode (e.g., "historical", "current", "forecast").
#' @param return_format Character string specifying the desired return type for the R function:
#'   \itemize{
#'     \item `"file"`: (Default) Downloads the data. If `output_file` is specified and exists, returns the path immediately. Otherwise, downloads to a temporary file (or `output_file`) and returns the path. Error responses are *not* written to the file.
#'     \item `"dataframe"`: Attempts to parse the response content (CSV or JSON) directly into a data frame or list. Requires `readr` and/or `jsonlite` packages.
#'     \item `"raw"`: Returns the raw `httr` response object.
#'   }
#' @param output_file Path where the downloaded data should be saved *only* when `return_format = "file"`. If specified and the file exists, the download is skipped. If `NULL` (default), a temporary file is used for successful downloads.
#' @param verbose Logical. If `TRUE`, prints standard informational messages (using `cli`). Defaults to `FALSE`.
#' @param debug Logical. If `TRUE`, prints detailed internal debugging messages. Defaults to `FALSE`.
#' @param timeout_seconds Request timeout in seconds. Passed to `httr::GET`.
#'
#' @examples \dontrun{
#' # Ensure necessary packages are installed
#' # install.packages(c("readr", "jsonlite", "cli", "httr", "glue"))
#'
#' # --- Example 1: Download to a specific file, first time (verbose) ---
#' target_file <- "vienna_monthly_temp_2023.csv"
#' if(file.exists(target_file)) file.remove(target_file) # Clean up for demo
#'
#' path1 <- geosphere_get_data(
#'     resource_id = "klima-v2-1m", parameters = "tl_mittel",
#'     start = "2023-01-01", end = "2023-12-31", station_ids = "11035", # Wien-Hohe Warte
#'     type = "station", verbose = TRUE, return_format = "file",
#'     output_file = target_file
#' )
#' # Prints URL, Fetching message, Writing message, Success message
#' print(path1)
#'
#' # --- Example 2: Call again (verbose) - should skip download ---
#' path2 <- geosphere_get_data(
#'     resource_id = "klima-v2-1m", parameters = "tl_mittel",
#'     start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
#'     type = "station", verbose = TRUE, return_format = "file",
#'     output_file = target_file # File now exists
#' )
#' # Should only print the "already exists" message
#' print(path2 == path1) # Should be TRUE, same path returned
#'
#' # --- Example 3: Call again (verbose=FALSE) - should print nothing ---
#' path3 <- geosphere_get_data(
#'     resource_id = "klima-v2-1m", parameters = "tl_mittel",
#'     start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
#'     type = "station", verbose = FALSE, return_format = "file",
#'     output_file = target_file # File now exists
#' )
#' # Should print nothing
#' print(path3 == path1) # Should be TRUE, same path returned
#'
#' # --- Example 4: Call again (debug=TRUE) - should print debug info ---
#' path4 <- geosphere_get_data(
#'     resource_id = "klima-v2-1m", parameters = "tl_mittel",
#'     start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
#'     type = "station", verbose = FALSE, debug = TRUE, return_format = "file",
#'     output_file = target_file # File now exists
#' )
#' # Should print all the "--- Debug: ..." messages, but not the cli messages
#' print(path4 == path1) # Should be TRUE
#'
#' # Clean up demo file
#' if(file.exists(target_file)) file.remove(target_file)
#' }
#'
#' @return Depends on `return_format`:
#'   - `"file"`: The path to the downloaded file (either `output_file` or a temporary path).
#'   - `"dataframe"`: A data frame (for CSV) or list/data frame (for JSON), parsed from the response. Requires `readr` or `jsonlite`.
#'   - `"raw"`: The raw `httr` response object.
#' @export
#' @importFrom httr GET modify_url stop_for_status content http_type http_error progress timeout status_code
#' @importFrom glue glue
#' @importFrom tools file_ext
#' @importFrom utils head modifyList str
#' @importFrom cli style_hyperlink cli_alert_info cli_alert_success cli_text # Import necessary cli functions
geosphere_get_data = function(
    resource_id,
    parameters = NULL,
    start = NULL,
    end = NULL,
    station_ids = NULL,
    output_format = "csv",
    ...,
    api_url = "https://dataset.api.hub.geosphere.at",
    version = "v1",
    type = "timeseries",
    mode = "historical",
    return_format = c("file", "dataframe", "raw"),
    output_file = NULL,
    verbose = FALSE, # Default verbose to FALSE
    debug = FALSE,   # Default debug to FALSE
    timeout_seconds = 120
) {
  # --- Input Validation and Setup ---
  return_format = match.arg(return_format)

  if (debug) {
    print(paste("--- Debug: verbose argument received as:", verbose))
    print(paste("--- Debug: output_file argument received as:", ifelse(is.null(output_file), "NULL", output_file)))
    print(paste("--- Debug: return_format determined as:", return_format))
  }

  if (missing(resource_id) || is.null(resource_id) || !nzchar(trimws(resource_id))) {
    stop("`resource_id` is required and cannot be missing, NULL, or empty.", call. = FALSE)
  }
  resource_id = trimws(as.character(resource_id)[1])
  if (return_format == "dataframe") {
    has_readr = requireNamespace("readr", quietly = TRUE)
    has_jsonlite = requireNamespace("jsonlite", quietly = TRUE)
    if (tolower(output_format) == "csv" && !has_readr) {
      if(verbose) cli::cli_alert_warning("Package 'readr' not found. Cannot return 'dataframe' for CSV. Falling back to return_format = 'file'. Install with {.code install.packages(\"readr\")}.")
      return_format = "file"
    }
    if (tolower(output_format) %in% c("json", "geojson") && !has_jsonlite) {
      if(verbose) cli::cli_alert_warning("Package 'jsonlite' not found. Cannot return 'dataframe' for JSON/GeoJSON. Falling back to return_format = 'file'. Install with {.code install.packages(\"jsonlite\")}.")
      return_format = "file"
    }
  }

  # *** Check for existing output file BEFORE API call ***
  if (return_format == "file" && !is.null(output_file)) {
    if (debug) print("--- Debug: Entered block to check existing file.")
    output_file_cleaned <- tryCatch(
      normalizePath(output_file, mustWork = FALSE),
      error = function(e) {
        if (debug) print(paste("--- Debug: Error normalizing path:", e$message))
        return(output_file) # Fallback
      }
    )
    if (debug) {
      print(paste("--- Debug: Provided output_file:", output_file))
      print(paste("--- Debug: Cleaned path for check:", output_file_cleaned))
    }

    file_exists_check <- file.exists(output_file_cleaned)
    if (debug) print(paste("--- Debug: Result of file.exists check:", file_exists_check))

    if (file_exists_check) {
      if (debug) print("--- Debug: File exists, entering block to return.")
      if (verbose) {
        if (debug) print("--- Debug: verbose is TRUE, attempting cli_text.")
        # Use cli_text for the standard informational message
        cli::cli_text("{.alert-info Output file {.path {output_file_cleaned}} already exists. Skipping download.}")
      } else {
        if (debug) print("--- Debug: verbose is FALSE, skipping message.")
      }
      if (debug) print(paste("--- Debug: Returning existing path:", output_file_cleaned))
      return(output_file_cleaned) # Return existing path
    } else {
      if (debug) print("--- Debug: File does not exist, proceeding to store intended path.")
      intended_output_path <- output_file_cleaned # Store for later
    }
  } else {
    if (debug) print(paste("--- Debug: Did NOT enter block to check existing file. Reason: return_format =", return_format, ", is.null(output_file) =", is.null(output_file)))
    intended_output_path <- NULL # Will use temp file or not returning file
  }
  # *** END FILE CHECK BLOCK ***

  # --- Construct Query Parameters --- (same as before)
  query_params = list()
  add_param = function(params, key, value) {
    if (!is.null(value)) {
      value_str = paste(as.character(value), collapse = ",")
      if (nzchar(value_str)) {
        params[[key]] = value_str
      }
    }
    return(params)
  }
  query_params = add_param(query_params, "parameters", parameters)
  query_params = add_param(query_params, "start", start)
  query_params = add_param(query_params, "end", end)
  query_params = add_param(query_params, "station_ids", station_ids)
  query_params = add_param(query_params, "output_format", output_format)
  additional_params = list(...)
  additional_params = Filter(Negate(is.null), additional_params)
  additional_params = lapply(additional_params, function(x) {
    if (is.factor(x)) as.character(x) else x
  })
  final_query_params = utils::modifyList(additional_params, query_params)


  # --- Construct URL --- (same version modification logic)
  version_path_segment = as.character(version)[1]
  if (!is.null(version_path_segment) && nzchar(version_path_segment)) {
    if (!startsWith(tolower(version_path_segment), "v")) {
      original_version_input = version_path_segment
      version_path_segment = paste0("v", version_path_segment)
      if (verbose) { # Use cli_alert_info for standard message
        cli::cli_alert_info("Input version was '{original_version_input}'. Using API path version: {version_path_segment}")
      }
    }
  } else {
    stop("API 'version' argument resulted in an invalid path segment (NULL or empty).", call. = FALSE)
  }
  base_path_segments = c(version_path_segment, type, mode, resource_id)
  base_url_path_part = paste(base_path_segments, collapse="/")

  # Warning check (same as before)
  query_params_no_format = final_query_params
  query_params_no_format$output_format = NULL
  if (length(query_params_no_format) == 0) {
    data_url_warn = paste(c(api_url, base_path_segments), collapse = "/")
    metadata_url_warn = paste0(data_url_warn, "/metadata")
    datasets_url_warn = file.path(api_url, version_path_segment, "datasets")
    warning(
      glue::glue(
        "No filter parameters (e.g., parameters, start, end, station_ids, ...) provided besides `output_format`.
        The request for '{resource_id}' might fail or return default/all data.
        Check required/optional parameters for the data endpoint: {cli::style_hyperlink(data_url_warn, data_url_warn)}
        Associated metadata endpoint: {cli::style_hyperlink(metadata_url_warn, metadata_url_warn)}
        Browse all datasets: {cli::style_hyperlink(datasets_url_warn, datasets_url_warn)}"
      ), call. = FALSE
    )
  }

  # Build the final URL
  final_url = httr::modify_url(
    api_url,
    path = base_path_segments,
    query = final_query_params
  )

  # Use cli_alert_info controlled by verbose
  if (verbose) {
    cli::cli_alert_info("Requesting URL: {cli::style_hyperlink(final_url, final_url)}")
  }

  # --- Perform Request (Fetch to memory first) ---
  if (verbose) { # Simple fetch message controlled by verbose
    cli::cli_alert_info("Attempting to fetch data from API...")
  }
  response = tryCatch({
    httr::GET(
      url = final_url,
      httr::timeout(timeout_seconds)
    )
  }, error = function(e) {
    stop(glue::glue("HTTP request failed for URL: {final_url}\nError: {e$message}"), call.=FALSE)
  })

  # --- Check for HTTP Errors (BEFORE processing/writing) ---
  if (httr::http_error(response)) {
    status <- httr::status_code(response)
    error_message = glue::glue("API request failed for resource '{resource_id}' with status {status}")
    error_details = NULL
    # Try to get more info from response body (same logic as before)
    response_content_raw = httr::content(response, as = "raw")
    if (length(response_content_raw) > 0) {
      response_text = tryCatch(readBin(response_content_raw, character()), error = function(e_utf8) {
        tryCatch(rawToChar(iconv(response_content_raw, from="latin1", to="UTF-8")), error = function(e_latin1) "<Could not decode error message body>")
      })
      if (!is.null(response_text)){
        parsed_json = tryCatch(jsonlite::fromJSON(response_text, simplifyVector = FALSE), error = function(e) NULL)
        if (!is.null(parsed_json)) {
          details = parsed_json$detail %||% parsed_json$message %||% parsed_json$error %||% parsed_json$title
          if (!is.null(details)) {
            if(is.list(details)) details = paste(names(details), unlist(details), sep = ": ", collapse = "; ")
            error_details = paste("API Message:", details)
          } else if (length(parsed_json) > 0) {
            error_details = paste("API Response (JSON structure):", utils::str(parsed_json, max.level=1))
          }
        } else {
          cleaned_text = gsub("[[:cntrl:]]", " ", response_text)
          error_details = paste("API Response Body (text, truncated):", substr(cleaned_text, 1, 300))
        }
      }
    }
    full_error_msg = paste(error_message, error_details, sep = "\n")
    stop(full_error_msg, call. = FALSE)
  }

  # --- Process Successful Response ---
  # At this point, the request was successful (status 2xx)

  if (return_format == "file") {
    # Determine final path if using temp file
    if (is.null(intended_output_path)) { # This means output_file was NULL, use temp
      file_ext = if (!is.null(final_query_params$output_format) && nzchar(final_query_params$output_format))
        paste0(".", tolower(final_query_params$output_format)) else ".tmp"
      output_file_path = tempfile(fileext = file_ext)
      if (verbose) cli::cli_alert_info("Download successful. Writing to temporary file: {.path {output_file_path}}")
    } else { # Use the path specified by the user
      output_file_path = intended_output_path
      if (verbose) cli::cli_alert_info("Download successful. Writing to specified file: {.path {output_file_path}}")
    }

    # Write the content fetched into memory to the determined file path
    raw_content <- httr::content(response, as = "raw")
    tryCatch({
      con <- file(output_file_path, "wb")
      on.exit(close(con), add = TRUE)
      writeBin(raw_content, con)
    }, error = function(e) {
      stop(glue::glue("Failed to write downloaded content to file: {output_file_path}\nError: {e$message}"), call.=FALSE)
    })

    # Use cli_alert_success controlled by verbose
    if (verbose) cli::cli_alert_success("Successfully wrote data to {.path {output_file_path}}")
    return(output_file_path)

  } else if (return_format == "dataframe") {
    # Parsing logic remains the same, using the 'response' object
    content_type = tolower(httr::http_type(response))
    api_output_format_lower = tolower(final_query_params$output_format %||% "")
    parse_as = NA
    content_type_main = sub(";.*", "", content_type)

    if (api_output_format_lower == "csv") parse_as = "csv"
    else if (api_output_format_lower %in% c("json", "geojson")) parse_as = "json"
    else {
      if (grepl("csv", content_type_main)) parse_as = "csv"
      else if (grepl("json", content_type_main)) parse_as = "json"
    }

    if (is.na(parse_as)) {
      # Use cli_alert_warning controlled by verbose
      if (verbose) cli::cli_alert_warning("Cannot automatically determine how to parse content type '{content_type}' or API format '{api_output_format_lower}'. Returning raw response object instead.")
      return(response) # Return raw response if parsing unclear
    }

    if (parse_as == "csv") {
      if (!requireNamespace("readr", quietly = TRUE)) stop("Package 'readr' required for return_format='dataframe' with CSV. Please install it.", call. = FALSE)
      csv_data = tryCatch(readr::read_csv(httr::content(response, as = "raw"), show_col_types = FALSE, locale = readr::locale(encoding = "UTF-8")),
                          warning = function(w) { if(verbose) cli::cli_alert_warning("Potential CSV parsing issue: {w$message}"); suppressWarnings(readr::read_csv(httr::content(response, as = "raw"), show_col_types = FALSE)) },
                          error = function(e){ stop("Failed to parse CSV content. Error: ", e$message, call.=FALSE) })
      if (verbose) cli::cli_alert_success("Data fetched and parsed as CSV data frame.")
      return(csv_data)

    } else if (parse_as == "json") {
      if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' required for return_format='dataframe' with JSON/GeoJSON. Please install it.", call. = FALSE)
      json_text = httr::content(response, as = "text", encoding = "UTF-8")
      json_data = tryCatch(jsonlite::fromJSON(json_text),
                           error = function(e) { stop("Failed to parse JSON content. Error: ", e$message, call.=FALSE) })
      if (verbose) cli::cli_alert_success("Data fetched and parsed as JSON.")
      return(json_data)
    }

  } else { # return_format == "raw"
    # Use cli_alert_success controlled by verbose
    if (verbose) cli::cli_alert_success("Data fetched, returning raw response object.")
    return(response)
  }
}

# Helper function (base R alternative to rlang::%||%)
`%||%` = function(x, y) {
  if (is.null(x)) y else x
}

# Make sure necessary packages are listed in DESCRIPTION if this is part of a package:
# Imports:
#   httr (>= 1.0.0 suggested for status_code),
#   glue,
#   tools,
#   utils,
#   cli      # <-- Ensure cli is listed here
# Suggests:
#   readr,
#   jsonlite
