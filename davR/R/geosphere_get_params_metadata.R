#' Get Parameter Metadata for a Geosphere Resource
#'
#' @description
#' Retrieves the metadata for a specific Geosphere API resource. This metadata
#' typically contains information about available parameters, stations (if applicable),
#' time ranges, required query parameters for the data endpoint, etc.
#'
#' @param resource_id Character string. The specific dataset or resource ID
#'   (e.g., "apolis_short-v1-1d-100m", "klima-v2-1h"). This is required.
#' @param type Character string. The data type (e.g., "grid", "station", "timeseries").
#'   Defaults to "timeseries". Ensure this matches the `resource_id`.
#' @param mode Character string. The data mode (e.g., "historical", "current").
#'   Defaults to "historical". Ensure this matches the `resource_id`.
#' @param api_url Base URL for the Geosphere API. Defaults to Geosphere Hub v1.
#' @param version API version string. Defaults to "v1".
#' @param user_agent A string to identify the client. Defaults to "davR".
#'
#' @return A list parsed from the JSON metadata response. The structure depends
#'   on the specific resource's metadata. It often contains details about
#'   `parameters`, `stations`, `timerange`, etc. Returns `NULL` if the request fails.
#'
#' @export
#' @importFrom httr GET modify_url stop_for_status content http_type user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_alert_danger cli_alert_info
#'
#' @examples
#' \dontrun{
#' # Example 1: Get metadata for a historical climate station dataset
#' try({
#'   klima_meta = geosphere_get_params_metadata(
#'     resource_id = "klima-v2-1h",
#'     type = "station",
#'     mode = "historical"
#'   )
#'   if (!is.null(klima_meta)) {
#'     print(names(klima_meta))
#'     # Look at available parameters
#'     if ("parameters" %in% names(klima_meta)) {
#'        print(head(klima_meta$parameters))
#'     }
#'   }
#' })
#'
#' # Example 2: Get metadata for a grid dataset
#' try({
#'   grid_meta = geosphere_get_params_metadata(
#'     resource_id = "spartacus-v2-1d-1km", # Example ID, check availability
#'     type = "grid",
#'     mode = "historical"
#'   )
#'   if (!is.null(grid_meta)) {
#'     print(names(grid_meta))
#'   }
#' })
#'
#' # Example 3: Non-existent resource (will likely cause an error)
#' # try(geosphere_get_params_metadata(resource_id = "non-existent-resource"))
#' }
geosphere_get_params_metadata = function(resource_id,
                                         type = "timeseries",
                                         mode = "historical",
                                         api_url = "https://dataset.api.hub.geosphere.at",
                                         version = "v1",
                                         user_agent = "davR") {

  # --- 1. Input Validation ---
  if (missing(resource_id) || !is.character(resource_id) || length(resource_id) != 1 || nchar(trimws(resource_id)) == 0) {
    stop("`resource_id` is required and must be a non-empty string.", call. = FALSE)
  }
  if (!is.character(type) || length(type) != 1 || nchar(trimws(type)) == 0) {
    stop("`type` must be a non-empty string (e.g., 'grid', 'station').", call. = FALSE)
  }
  if (!is.character(mode) || length(mode) != 1 || nchar(trimws(mode)) == 0) {
    stop("`mode` must be a non-empty string (e.g., 'historical', 'current').", call. = FALSE)
  }
  resource_id = trimws(resource_id)
  type = trimws(type)
  mode = trimws(mode)

  # --- 2. Construct Metadata URL ---
  # Path segments: version / type / mode / resource_id / metadata
  metadata_path = paste(version, type, mode, resource_id, "metadata", sep = "/")
  metadata_url = httr::modify_url(api_url, path = metadata_path)

  # --- 3. Perform HTTP GET Request ---
  ua = httr::user_agent(user_agent)
  response = tryCatch(
    httr::GET(metadata_url, ua),
    error = function(e) {
      cli::cli_alert_danger("HTTP request failed for metadata URL {.url {metadata_url}}")
      cli::cli_alert_danger("Error: {e$message}")
      return(NULL)
    }
  )

  if (is.null(response)) return(NULL) # Exit if GET failed

  # --- 4. Check HTTP Status & Parse ---
  # Use tryCatch to handle both HTTP errors from stop_for_status
  # and parsing errors from fromJSON gracefully.
  metadata_content = NULL # Initialize
  error_occurred = FALSE  # Flag

  tryCatch(
    {
      # Check for HTTP client/server errors (4xx, 5xx)
      httr::stop_for_status(response, task = paste("fetch metadata for", resource_id))

      # --- 5. Check Content Type (Optional but good practice) ---
      if (!grepl("application/json", httr::http_type(response), ignore.case = TRUE)) {
        warning("API did not return JSON content as expected for metadata. Content type was: ",
                httr::http_type(response), ". Attempting to parse anyway.", call. = FALSE)
      }

      # --- 6. Parse JSON Response ---
      response_text = httr::content(response, as = "text", encoding = "UTF-8")
      if (!nzchar(response_text)) { # Check for empty response body
        stop("Received empty response body from metadata endpoint.", call. = FALSE)
      }
      # Parse using jsonlite
      metadata_content = jsonlite::fromJSON(response_text, simplifyVector = TRUE)

    },
    # --- Error Handling within tryCatch ---
    # Catch HTTP errors specifically from stop_for_status
    http_error = function(e) {
      error_occurred <<- TRUE # Set flag using <<- to modify variable in parent scope
      cli::cli_alert_danger("Failed to fetch metadata for resource '{resource_id}'")
      # Try to provide a cleaner error message
      err_msg = conditionMessage(e)
      status_match = regexpr("\\b\\d{3}\\b", err_msg) # Look for 3-digit status code
      if (attr(status_match, "match.length") > 0) {
        status = regmatches(err_msg, status_match)
        cli::cli_alert_danger("HTTP Status: {status}")
      } else {
        cli::cli_alert_danger("HTTP Error (check URL and resource details)")
      }
      # Attempt to show part of the response body for context
      resp_body = NULL
      if (!is.null(e$response) && !is.null(e$response$content) && length(e$response$content) > 0) {
        resp_body = tryCatch(rawToChar(e$response$content), error=function(e2) NULL)
      }
      if (!is.null(resp_body)) {
        cleaned_body = gsub('[[:cntrl:]]',' ', resp_body) # Clean control chars
        cli::cli_alert_danger("API Response (partial): {substr(cleaned_body, 1, 200)}")
      }

    },
    # Catch other errors (e.g., network, parsing JSON)
    error = function(e) {
      error_occurred <<- TRUE # Set flag
      cli::cli_alert_danger("Failed to process metadata response for resource '{resource_id}'")
      cli::cli_alert_danger("Error: {e$message}")
    }
  ) # End tryCatch

  # --- 7. Return Result ---
  if (error_occurred) {
    return(NULL)
  } else {
    # Success! Return the parsed metadata list
    return(metadata_content)
  }
}
