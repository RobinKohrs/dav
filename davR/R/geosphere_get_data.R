#' Get data from Geosphere Austria's Open Data Hub
#'
#' @description
#' Constructs a URL and fetches data from the Geosphere API based on the provided parameters.
#' The function allows fetching data as a file path (default), directly into an R object (data frame),
#' or as the raw HTTP response.
#'
#' See the Geosphere API documentation for details on available endpoints and parameters:
#' \itemize{
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/docs/getting-started.html}{Getting Started}
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/docs/user-guide/resource.html#resources}{Resources}
#'   \item \href{https://dataset.api.hub.geosphere.at/v1/datasets}{Datasets Overview}
#' }
#' Example endpoint: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km}{SPARTACUS Monthly}
#' Example metadata: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km/metadata}{SPARTACUS Monthly Metadata}
#'
#' @param resource_id The specific dataset or resource ID (e.g., "klima-v2-1m"). This is usually the only required argument.
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
#' # Example 3: Get metadata as a list (JSON)
#' try({
#' metadata = geosphere_get_data(
#'     resource_id = "klima-v2-1h",
#'     type = "station",
#'     output_format = "json", # Request JSON from API
#'     return_format = "dataframe" # Parse JSON to list/df
#' )
#' print(names(metadata))
#' }, silent = TRUE)
#'
#' # Example 4: Using ... for a less common parameter (e.g., spatial filter)
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
#' @importFrom utils read.csv head
geosphere_get_data = function(
    resource_id, # Changed order, no default
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
    # Input Validation and Setup
    return_format = match.arg(return_format)
    if (return_format == "dataframe") {
        # Check necessary packages silently, warn later if parsing fails
        has_readr = requireNamespace("readr", quietly = TRUE)
        has_jsonlite = requireNamespace("jsonlite", quietly = TRUE)
        if (tolower(output_format) == "csv" && !has_readr) {
            warning(
                "Package 'readr' not found. Cannot return 'dataframe' for CSV format. Try installing with install.packages(\"readr\"). Falling back to return_format = \"file\".",
                call. = FALSE
            )
            return_format = "file"
        }
        if (tolower(output_format) == "json" && !has_jsonlite) {
            warning(
                "Package 'jsonlite' not found. Cannot return 'dataframe' for JSON format. Try installing with install.packages(\"jsonlite\"). Falling back to return_format = \"file\".",
                call. = FALSE
            )
            return_format = "file"
        }
    }

    # Construct query parameters list, giving precedence to explicit args
    query_params = list()
    if (!is.null(parameters))
        query_params$parameters = paste(parameters, collapse = ",")
    if (!is.null(start)) query_params$start = start
    if (!is.null(end)) query_params$end = end
    if (!is.null(station_ids))
        query_params$station_ids = paste(station_ids, collapse = ",")
    if (!is.null(output_format)) query_params$output_format = output_format

    # Merge explicit params with ... args, ... overrides explicit if names clash (standard R behavior)
    additional_params = list(...)
    final_query_params = utils::modifyList(query_params, additional_params) # Keep additional first to let explicit args override if needed later? No, httr::modify_url handles list merging correctly.

    # Check if essential query parameters seem missing (basic check)
    essential_missing = is.null(final_query_params$parameters) &&
        is.null(final_query_params$start) &&
        is.null(final_query_params$station_ids) &&
        length(additional_params) == 0 # Only warn if ALL common & ... are missing

    if (essential_missing) {
        base_path_url = paste(
            api_url,
            version,
            type,
            mode,
            resource_id,
            sep = "/"
        )
        metadata_url = paste0(base_path_url, "/metadata")
        datasets_url = file.path(api_url, version, "datasets")
        warning(
            glue::glue(
                "No common query parameters (parameters, start, end, station_ids) or additional parameters via `...` provided.
        The request might fail or return default data.
        Check required parameters for '{resource_id}' at: {cli::style_hyperlink(base_path_url, base_path_url)}
        Metadata: {cli::style_hyperlink(metadata_url, metadata_url)}
        Browse datasets: {cli::style_hyperlink(datasets_url, datasets_url)}"
            ),
            call. = FALSE
        )
    }

    # Construct the full URL path segments
    full_path = paste(version, type, mode, resource_id, sep = "/")

    # Build the final URL
    final_url = httr::modify_url(
        api_url,
        path = full_path,
        query = final_query_params
    )

    if (verbose) {
        message("Requesting URL: ", final_url)
    }

    # Determine output destination based on return_format
    if (return_format == "file") {
        output_file_path = if (is.null(output_file)) {
            # Create temp file with appropriate extension if possible
            file_ext = if (!is.null(output_format))
                paste0(".", tolower(output_format)) else ".tmp"
            tempfile(fileext = file_ext)
        } else {
            output_file
        }
        write_config = httr::write_disk(output_file_path, overwrite = TRUE)
    } else {
        write_config = NULL # Fetch to memory
    }

    # Perform the GET request
    response = httr::GET(
        url = final_url,
        write_config, # NULL if fetching to memory
        httr::timeout(timeout_seconds),
        if (verbose) httr::progress()
    )

    # Check for HTTP errors - improved message attempt
    if (httr::http_error(response)) {
        error_message = glue::glue("fetch data from {resource_id} failed")
        # Try to get more info from response body
        error_body = tryCatch(
            {
                parsed_content = httr::content(
                    response,
                    as = "parsed",
                    encoding = "UTF-8"
                )
                # Look for common error message fields (adjust based on API specifics)
                details = parsed_content$detail %||%
                    parsed_content$message %||%
                    parsed_content$error %||%
                    NULL
                if (is.list(details))
                    details = paste(
                        names(details),
                        unlist(details),
                        sep = ": ",
                        collapse = "; "
                    )
                if (!is.null(details) && nzchar(details))
                    paste("API Error:", details) else NULL
            },
            error = function(e) NULL
        ) # Ignore parsing errors

        full_error_msg = paste(error_message, error_body, sep = "\n")
        httr::stop_for_status(response, task = full_error_msg) # stop_for_status provides status code info
    }

    # Process response based on return_format
    if (return_format == "file") {
        if (verbose) message("Data saved to: ", output_file_path)
        return(output_file_path)
    } else if (return_format == "dataframe") {
        content_type = tolower(httr::http_type(response))
        api_output_format_lower = tolower(
            final_query_params$output_format %||% ""
        ) # Use the requested format

        # Prioritize requested format, then content type for parsing decision
        if (api_output_format_lower == "csv" || grepl("csv", content_type)) {
            if (!requireNamespace("readr", quietly = TRUE))
                stop(
                    "Package 'readr' required for return_format='dataframe' with CSV. Please install it.",
                    call. = FALSE
                )
            return(httr::content(
                response,
                as = "parsed",
                type = "text/csv",
                encoding = "UTF-8"
            ))
        } else if (
            api_output_format_lower %in%
                c("json", "geojson") ||
                grepl("json", content_type)
        ) {
            if (!requireNamespace("jsonlite", quietly = TRUE))
                stop(
                    "Package 'jsonlite' required for return_format='dataframe' with JSON. Please install it.",
                    call. = FALSE
                )
            return(jsonlite::fromJSON(httr::content(
                response,
                as = "text",
                encoding = "UTF-8"
            )))
        } else {
            warning(
                "Cannot automatically parse content type '",
                content_type,
                "' or API format '",
                api_output_format_lower,
                "' into a data frame. Returning raw response object instead.",
                call. = FALSE
            )
            return(response) # Fallback to raw response
        }
    } else {
        # return_format == "raw"
        return(response)
    }
}

# Helper function (base R alternative to rlang::%||%)
`%||%` = function(x, y) {
    if (is.null(x)) y else x
}

# Add import for %||% if moved outside or just keep definition here.
# Consider adding @importFrom utils modifyList if not already standard import.
