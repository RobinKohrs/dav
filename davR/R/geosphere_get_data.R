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
#' @param version API version string.
#' @param type Data type (e.g., "timeseries", "station", "grid").
#' @param mode Data mode (e.g., "historical", "current", "forecast").
#' @param return_format Character string specifying the desired return type for the R function:
#'   \itemize{
#'     \item `"file"`: (Default) Downloads the data to a temporary file (or `output_file` if specified) and returns the file path.
#'     \item `"dataframe"`: Attempts to parse the response content (CSV or JSON) directly into a data frame or list. Requires `readr` and/or `jsonlite` packages.
#'     \item `"raw"`: Returns the raw `httr` response object.
#'   }
#' @param output_file Path where the downloaded data should be saved *only* when `return_format = "file"`. If `NULL` (default), a temporary file is used.
#' @param verbose Logical. If `TRUE`, prints the constructed URL and shows download progress.
#' @param timeout_seconds Request timeout in seconds. Passed to `httr::GET`.
#'
#' @examples \dontrun{
#' # Ensure necessary packages are installed for 'dataframe' return format
#' # install.packages(c("readr", "jsonlite"))
#'
#' # Example 1: Get monthly climate data for a station, save to temp file (default)
#' temp_csv_path = geosphere_get_data(
#'     resource_id = "klima-v2-1m",
#'     parameters = "tl_mittel",
#'     start = "2023-01-01",
#'     end = "2023-12-31",
#'     station_ids = "5925",
#'     output_format = "csv", # API format is CSV
#'     type = "station"
#'     # return_format defaults to "file"
#' )
#' print(temp_csv_path)
#' # data = readr::read_csv(temp_csv_path) # Optionally read the data
#'
#' # Example 2: Get hourly data and return directly as a data frame
#' start_time = "2024-04-06T05:00:00"
#' end_time = "2024-04-06T17:00:00"
#' try({ # Wrap in try in case readr is not installed or parsing fails
#' hourly_data = geosphere_get_data(
#'     resource_id = "klima-v2-1h",
#'     parameters = "tl",
#'     start = start_time,
#'     end = end_time,
#'     station_ids = 5925, # Numeric ID works too, converted to character
#'     output_format = "csv", # API format
#'     type = "station",
#'     return_format = "dataframe", # Request data frame directly
#'     verbose = TRUE
#' )
#' print(head(hourly_data))
#' }, silent = TRUE)
#'
#' # Example 3: Using ... for a less common parameter (e.g., spatial filter)
#' # Hypothetical example - check API docs for actual parameters
#' grid_data_path = geosphere_get_data(
#'     resource_id = "spartacus-v2-1d-1km",
#'     parameters = "t_2m",
#'     start = "2023-05-01",
#'     end = "2023-05-01",
#'     bbox = "10,47,11,48", # Passed via ...
#'     type = "grid",
#'     output_format = "netcdf" # Assuming API supports this
#' )
#' print(grid_data_path)
#'
#' # Example 4: Demonstrating the resource_id check (will cause an error)
#' # try(geosphere_get_data())
#' # try(geosphere_get_data(resource_id = NULL))
#' # try(geosphere_get_data(resource_id = "   "))
#'
#' # --- How to get METADATA manually ---
#' # You need to construct the specific metadata URL and use httr directly
#' metadata_url <- "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v2-1h/metadata"
#' response <- httr::GET(metadata_url)
#' httr::stop_for_status(response) # Check for errors
#' if (requireNamespace("jsonlite", quietly = TRUE)) {
#'   metadata_list <- jsonlite::fromJSON(httr::content(response, as = "text", encoding = "UTF-8"))
#'   print(names(metadata_list))
#'   print(head(metadata_list$parameters))
#' } else {
#'    print("Install jsonlite to parse the metadata JSON")
#' }
#' # ---
#' }
#'
#' @return Depends on `return_format`:
#'   - `"file"`: The path to the downloaded file.
#'   - `"dataframe"`: A data frame (for CSV) or list/data frame (for JSON), parsed from the response. Requires `readr` or `jsonlite`.
#'   - `"raw"`: The raw `httr` response object.
#' @export
#' @importFrom httr GET modify_url stop_for_status write_disk content http_type http_error progress timeout
#' @importFrom glue glue
#' @importFrom tools file_ext
#' @importFrom utils read.csv head modifyList
#' @importFrom cli style_hyperlink
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
    type = "timeseries", # Changed default
    mode = "historical",
    return_format = c("file", "dataframe", "raw"),
    output_file = NULL, # Default changed to NULL
    verbose = FALSE,
    timeout_seconds = 120
) {
  # --- Input Validation and Setup ---

  # Validate return_format first
  return_format = match.arg(return_format)

  # **NEW**: Check if resource_id is provided and valid
  if (missing(resource_id) || is.null(resource_id) || !nzchar(trimws(resource_id))) {
    stop(
      "`resource_id` is required and cannot be missing, NULL, or empty.",
      call. = FALSE
    )
  }
  # Ensure resource_id is a single string after validation
  resource_id = trimws(as.character(resource_id)[1])

  # Check necessary packages for dataframe format
  if (return_format == "dataframe") {
    has_readr = requireNamespace("readr", quietly = TRUE)
    has_jsonlite = requireNamespace("jsonlite", quietly = TRUE)
    if (tolower(output_format) == "csv" && !has_readr) {
      warning(
        "Package 'readr' not found. Cannot return 'dataframe' for CSV format. Try installing with install.packages(\"readr\"). Falling back to return_format = \"file\".",
        call. = FALSE
      )
      return_format = "file"
    }
    if (tolower(output_format) %in% c("json", "geojson") && !has_jsonlite) {
      # Updated check for both json and geojson
      warning(
        "Package 'jsonlite' not found. Cannot return 'dataframe' for JSON/GeoJSON format. Try installing with install.packages(\"jsonlite\"). Falling back to return_format = \"file\".",
        call. = FALSE
      )
      return_format = "file"
    }
  }

  # --- Construct Query Parameters ---
  query_params = list()
  # Helper to safely add non-NULL, non-empty parameters
  add_param = function(params, key, value) {
    if (!is.null(value)) {
      # Convert potential numeric station_ids etc. to character before pasting
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

  # Merge explicit params with ... args
  additional_params = list(...)
  # Ensure additional params are also cleaned (e.g., remove NULLs, convert factors)
  additional_params = Filter(Negate(is.null), additional_params)
  additional_params = lapply(additional_params, function(x) {
    if (is.factor(x)) as.character(x) else x
  })
  # Give explicit parameters precedence if names clash
  final_query_params = utils::modifyList(additional_params, query_params)


  # --- Construct URL ---
  # Base path segments for the main data resource
  base_path_segments = c(version, type, mode, resource_id)
  base_url_path_part = paste(base_path_segments, collapse="/") # For warning message

  # Check if *any* filtering parameters seem missing (excluding output_format)
  query_params_no_format = final_query_params
  query_params_no_format$output_format = NULL # Exclude format from check
  if (length(query_params_no_format) == 0) {
    # Construct potential data and metadata URLs for the warning message
    data_url_warn = paste(c(api_url, base_path_segments), collapse = "/")
    metadata_url_warn = paste0(data_url_warn, "/metadata")
    datasets_url_warn = file.path(api_url, version, "datasets")
    warning(
      glue::glue(
        "No filter parameters (e.g., parameters, start, end, station_ids, ...) provided besides `output_format`.
        The request for '{resource_id}' might fail or return default/all data.
        Check required/optional parameters for the data endpoint: {cli::style_hyperlink(data_url_warn, data_url_warn)}
        Associated metadata endpoint: {cli::style_hyperlink(metadata_url_warn, metadata_url_warn)}
        Browse all datasets: {cli::style_hyperlink(datasets_url_warn, datasets_url_warn)}"
      ),
      call. = FALSE
    )
  }

  # Build the final URL using httr::modify_url which handles base URL and path segments
  final_url = httr::modify_url(
    api_url,
    path = base_path_segments, # Pass segments as vector or single string
    query = final_query_params
  )

  if (verbose) {
    message("Requesting URL: ", final_url)
  }

  # --- Prepare for Download ---
  if (return_format == "file") {
    output_file_path = if (is.null(output_file)) {
      # Create temp file with appropriate extension if possible
      file_ext = if (!is.null(final_query_params$output_format) && nzchar(final_query_params$output_format))
        paste0(".", tolower(final_query_params$output_format)) else ".tmp"
      tempfile(fileext = file_ext)
    } else {
      output_file
    }
    write_config = httr::write_disk(output_file_path, overwrite = TRUE)
    if (verbose) message("Will save data to: ", output_file_path)
  } else {
    write_config = NULL # Fetch to memory
  }

  # --- Perform Request ---
  response = tryCatch({
    httr::GET(
      url = final_url,
      write_config, # NULL if fetching to memory
      httr::timeout(timeout_seconds),
      if (verbose && return_format == "file") httr::progress() else NULL # Progress only useful for file downloads
    )
  }, error = function(e) {
    # Catch DNS resolution errors, timeouts etc.
    stop(glue::glue("HTTP request failed for URL: {final_url}\nError: {e$message}"), call.=FALSE)
  })

  # --- Check for HTTP Errors ---
  if (httr::http_error(response)) {
    error_message = glue::glue("API request failed for resource '{resource_id}'")
    error_details = NULL
    # Try to get more info from response body
    response_content_raw = httr::content(response, as = "raw")
    if (length(response_content_raw) > 0) {
      response_text = tryCatch(
        # Try UTF-8 first, fallback to Latin1 if it fails
        rawToChar(response_content_raw),
        error = function(e_utf8) {
          tryCatch(
            rawToChar(iconv(response_content_raw, from="latin1", to="UTF-8")), # Try converting from latin1
            error = function(e_latin1) NULL
          )
        }
      )
      if (!is.null(response_text)){
        # Try parsing as JSON first, as it's common for errors
        parsed_json = tryCatch(
          jsonlite::fromJSON(response_text, simplifyVector = FALSE),
          error = function(e) NULL
        )
        if (!is.null(parsed_json)) {
          # Look for common error fields (adjust based on API specifics)
          details = parsed_json$detail %||% parsed_json$message %||% parsed_json$error %||% parsed_json$title
          if (!is.null(details)) {
            if(is.list(details)) details = paste(names(details), unlist(details), sep = ": ", collapse = "; ")
            error_details = paste("API Message:", details)
          } else if (length(parsed_json) > 0) {
            # If no specific error field, show structure or snippet
            error_details = paste("API Response (JSON structure):", utils::str(parsed_json, max.level=1))
          }
        } else {
          # If not JSON or parsing failed, show first few lines of text, cleaning control chars
          cleaned_text = gsub("[[:cntrl:]]", " ", response_text) # Remove control characters
          error_details = paste("API Response Body (text, truncated):", substr(cleaned_text, 1, 250))
        }
      }
    }

    full_error_msg = paste(error_message, error_details, sep = "\n")
    # stop_for_status provides status code info automatically
    httr::stop_for_status(response, task = full_error_msg)
  }

  # --- Process Successful Response ---
  if (return_format == "file") {
    if (verbose) message("Download successful.")
    return(output_file_path)

  } else if (return_format == "dataframe") {
    content_type = tolower(httr::http_type(response))
    # Use the *actual* content type returned if output_format wasn't specified or didn't match
    api_output_format_lower = tolower(final_query_params$output_format %||% "")

    # Decide parsing based on requested format primarily, fallback to content-type
    parse_as = NA
    content_type_main = sub(";.*", "", content_type) # Get main type like 'text/csv'

    # Prioritize explicit request if it matches known types
    if (api_output_format_lower == "csv") parse_as = "csv"
    else if (api_output_format_lower %in% c("json", "geojson")) parse_as = "json"
    else { # If format not specified or unknown, guess from Content-Type
      if (grepl("csv", content_type_main)) parse_as = "csv"
      else if (grepl("json", content_type_main)) parse_as = "json"
    }

    if (is.na(parse_as)) {
      warning(
        "Cannot automatically determine how to parse content type '", content_type,
        "' or API format '", api_output_format_lower,
        "'. Returning raw response object instead.", call. = FALSE
      )
      return(response)
    }

    # Perform parsing
    if (parse_as == "csv") {
      if (!requireNamespace("readr", quietly = TRUE)) {
        stop("Package 'readr' required for return_format='dataframe' with CSV. Please install it.", call. = FALSE)
      }
      # Use readr::read_csv for better parsing, get raw content first
      raw_content = httr::content(response, as = "raw")
      # Attempt to read with UTF-8, potentially add locale info if needed
      csv_data = tryCatch(
        readr::read_csv(raw_content, show_col_types = FALSE, locale = readr::locale(encoding = "UTF-8")),
        warning = function(w) {
          # If warning about UTF-8, maybe try Latin1? Or just let it pass.
          message("Potential CSV encoding issue: ", w$message)
          # Suppress warning temporarily and retry or return result with warning
          suppressWarnings(readr::read_csv(raw_content, show_col_types = FALSE))
        },
        error = function(e){
          stop("Failed to parse CSV content. Error: ", e$message, call.=FALSE)
        }
      )
      return(csv_data)

    } else if (parse_as == "json") {
      if (!requireNamespace("jsonlite", quietly = TRUE)) {
        stop("Package 'jsonlite' required for return_format='dataframe' with JSON/GeoJSON. Please install it.", call. = FALSE)
      }
      # Get text content, ensuring correct encoding if possible
      json_text = httr::content(response, as = "text", encoding = "UTF-8")
      json_data = tryCatch(
        jsonlite::fromJSON(json_text),
        error = function(e) {
          stop("Failed to parse JSON content. Error: ", e$message, call.=FALSE)
        }
      )
      return(json_data)
    }

  } else { # return_format == "raw"
    return(response)
  }
}

# Helper function (base R alternative to rlang::%||%)
`%||%` = function(x, y) {
  if (is.null(x)) y else x
}

# Make sure necessary packages are listed in DESCRIPTION if this is part of a package:
# Imports:
#   httr,
#   glue,
#   tools,
#   utils,
#   cli      (optional, for styled links in warnings)
# Suggests:
#   readr,
#   jsonlite
