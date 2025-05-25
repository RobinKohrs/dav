#' Get data from Geosphere Austria's Open Data Hub
#'
#' @description
#' Fetches data from Geosphere API. Handles common parameters and returns data
#' as a file path, data frame, or raw response. Returns NULL on failure.
#' Provides a single concluding success or failure message with emoji.
#' If verbose=TRUE, prints the Requesting URL, then the single concluding message.
#'
#' @param resource_id Required dataset ID.
#' @param parameters Optional parameter IDs.
#' @param start Optional start date/time string.
#' @param end Optional end date/time string.
#' @param station_ids Optional station IDs.
#' @param output_format API output format (e.g., "csv").
#' @param ... Additional API query parameters.
#' @param api_url Base API URL.
#' @param version API version (e.g., "v1").
#' @param type API data type (e.g., "timeseries").
#' @param mode API data mode (e.g., "historical").
#' @param return_format R function return: "file", "dataframe", "raw".
#' @param output_file Path for `return_format = "file"`.
#' @param verbose If `TRUE`, prints "Requesting URL" message. Key success/fail messages always print.
#' @param debug Print detailed debug messages?
#' @param timeout_seconds Request timeout.
#'
#' @return Path, data frame, or httr response; NULL on failure.
#' @export
#' @importFrom httr GET modify_url content http_type http_error timeout status_code
#' @importFrom glue glue
#' @importFrom cli style_hyperlink cli_alert_info cli_alert_success cli_text cli_alert_warning cli_warn style_bold col_red col_green
geosphere_get_data <- function(
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
    verbose = FALSE, # verbose now ONLY controls "Requesting URL" and some specific warnings
    debug = FALSE,
    timeout_seconds = 30) {
  emoji_success <- "\U2705"
  emoji_fail <- "\U274C"
  emoji_network_fail <- "\U1F6AB"

  return_format <- match.arg(return_format)
  if (debug) print(paste("--- Debug: Start geosphere_get_data. Return format:", return_format, "Verbose:", verbose))

  if (missing(resource_id) || is.null(resource_id) || !nzchar(trimws(resource_id))) {
    stop("`resource_id` is essential and cannot be empty.", call. = FALSE)
  }
  resource_id <- trimws(as.character(resource_id)[1])

  if (return_format == "dataframe") {
    if (tolower(output_format) == "csv" && !requireNamespace("readr", quietly = TRUE)) {
      cli::cli_alert_warning("Package 'readr' needed for CSV to dataframe. Falling back to 'file' format. Install 'readr'.")
      return_format <- "file"
    }
    if (tolower(output_format) %in% c("json", "geojson") && !requireNamespace("jsonlite", quietly = TRUE)) {
      cli::cli_alert_warning("Package 'jsonlite' needed for JSON to dataframe. Falling back to 'file' format. Install 'jsonlite'.")
      return_format <- "file"
    }
  }

  intended_output_path <- NULL
  if (return_format == "file" && !is.null(output_file)) {
    output_file_cleaned <- tryCatch(normalizePath(output_file, mustWork = FALSE), error = function(e) output_file)
    if (file.exists(output_file_cleaned)) {
      # This informational message about skipping can still be controlled by verbose
      if (verbose) cli::cli_text("{.alert-info File {.path {output_file_cleaned}} already exists. {cli::col_green('Skipping download.')}}")
      return(output_file_cleaned)
    }
    intended_output_path <- output_file_cleaned
  }

  query_params <- list()
  add_param <- function(p_list, key, val) {
    if (!is.null(val)) p_list[[key]] <- paste(as.character(val), collapse = ",")
    return(p_list)
  }
  query_params <- add_param(query_params, "parameters", parameters)
  query_params <- add_param(query_params, "start", start)
  query_params <- add_param(query_params, "end", end)
  query_params <- add_param(query_params, "station_ids", station_ids)
  query_params <- add_param(query_params, "output_format", output_format)
  additional_api_params <- list(...)
  final_query_params <- utils::modifyList(additional_api_params, query_params)

  version_str <- as.character(version)[1]
  if (!startsWith(tolower(version_str), "v")) version_str <- paste0("v", version_str)
  api_path <- paste(version_str, type, mode, resource_id, sep = "/")
  final_url <- httr::modify_url(api_url, path = api_path, query = final_query_params)

  # "Requesting URL" is now the primary message controlled by verbose
  if (verbose) {
    cli::cli_alert_info("Requesting URL: {cli::style_hyperlink(final_url, final_url)}")
  }
  if (debug) print(paste("--- Debug: Final URL:", final_url))

  response <- tryCatch(
    {
      # "Attempting to fetch" message removed from here
      httr::GET(url = final_url, httr::timeout(as.numeric(timeout_seconds)))
    },
    error = function(e) {
      failed_text <- cli::style_bold(cli::col_red("Geosphere Network Error"))
      url_link <- cli::style_hyperlink(final_url, final_url)
      cli::cli_warn(
        c(
          glue::glue("{emoji_network_fail} {failed_text}: Could not connect to {url_link}."),
          glue::glue("Details: {e$message}")
        ),
        .call = NULL
      )
      return(NULL)
    }
  )

  if (is.null(response)) {
    return(NULL)
  }

  if (httr::http_error(response)) {
    status <- httr::status_code(response)
    error_details_text <- NULL
    response_body_text <- tryCatch(
      {
        httr::content(response, as = "text", encoding = "UTF-8")
      },
      error = function(e) NULL
    )

    if (!is.null(response_body_text) && nzchar(response_body_text)) {
      error_json <- tryCatch(jsonlite::fromJSON(response_body_text, simplifyVector = FALSE), error = function(e) NULL)
      if (!is.null(error_json)) {
        api_msg <- error_json$detail %||% error_json$message %||% error_json$error %||% error_json$title
        if (!is.null(api_msg)) {
          if (is.list(api_msg)) api_msg <- paste(names(api_msg), sapply(api_msg, paste, collapse = ", "), sep = ": ", collapse = "; ")
          error_details_text <- paste("API Message:", paste(unlist(api_msg), collapse = "; "))
        } else {
          error_details_text <- "API returned JSON error, but no standard message field."
        }
      } else {
        error_details_text <- paste("API Body (text, truncated):", substr(response_body_text, 1, 200))
      }
    }
    if (is.null(error_details_text) && status != 204) error_details_text <- "<No details in error body>"

    failed_text <- cli::style_bold(cli::col_red("Geosphere Download Failed"))
    url_link <- cli::style_hyperlink(final_url, final_url)
    warn_msg_parts <- c(glue::glue("{emoji_fail} {failed_text}: {url_link} (Status: {status})."))
    if (!is.null(error_details_text) && verbose) { # Only add details if verbose
      warn_msg_parts <- c(warn_msg_parts, glue::glue("Details: {error_details_text}"))
    }
    cli::cli_warn(warn_msg_parts, .call = NULL)
    return(NULL)
  }

  if (debug) print(paste("--- Debug: HTTP Success. Status:", httr::status_code(response)))

  # --- 6. Process Successful Response based on return_format ---
  if (return_format == "file") {
    output_file_to_write <- intended_output_path
    if (is.null(output_file_to_write)) {
      ext <- final_query_params$output_format %||% "tmp"
      output_file_to_write <- tempfile(fileext = paste0(".", ext))
      # "Writing to temp file" message removed from here
    } else {
      # "Writing to specified file" message removed from here
    }

    dir_path <- dirname(output_file_to_write)
    if (!dir.exists(dir_path)) dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)

    raw_bytes <- httr::content(response, as = "raw")
    tryCatch(
      {
        writeBin(raw_bytes, output_file_to_write)
        cli::cli_alert_success("{emoji_success} Data {cli::col_green('written to')} {.path {output_file_to_write}}")
        return(output_file_to_write)
      },
      error = function(e) {
        cli::cli_warn(
          c(
            glue::glue("{emoji_fail} Failed to write to file: {.path {output_file_to_write}}."),
            glue::glue("Details: {e$message}")
          ), # Details might be useful even if not verbose
          .call = NULL
        )
        return(NULL)
      }
    )
  } else if (return_format == "dataframe") {
    if (httr::status_code(response) == 204) {
      cli::cli_alert_info(glue::glue("{emoji_success} API returned 204 No Content (Success, no data).")) # Info for 204
      return(NULL)
    }

    api_fmt <- tolower(final_query_params$output_format %||% "")
    content_type <- tolower(httr::http_type(response))
    parse_attempt <- NA
    if (api_fmt == "csv" || grepl("csv", content_type) || grepl("text/plain", content_type)) {
      parse_attempt <- "csv"
    } else if (api_fmt %in% c("json", "geojson") || grepl("json", content_type)) parse_attempt <- "json"

    if (is.na(parse_attempt)) {
      cli::cli_alert_warning(glue::glue("{emoji_fail} Cannot determine parsing method for API format '{api_fmt}' / content type '{content_type}'. Returning NULL."))
      return(NULL)
    }

    response_text <- httr::content(response, as = "text", encoding = "UTF-8")
    if (is.null(response_text) || !nzchar(response_text)) {
      # This is a failure to get content, even if status was 200 (should be rare if not 204)
      cli::cli_alert_warning(glue::glue("{emoji_fail} API content is empty after successful fetch. Cannot parse to dataframe."))
      return(NULL)
    }

    parsed_object <- NULL
    parsing_error_details <- NULL
    if (parse_attempt == "csv") {
      parsed_object <- tryCatch(readr::read_csv(response_text, show_col_types = FALSE, guess_max = 10000),
        error = function(e) {
          parsing_error_details <<- e$message
          NULL
        }
      )
    } else if (parse_attempt == "json") {
      parsed_object <- tryCatch(jsonlite::fromJSON(response_text),
        error = function(e) {
          parsing_error_details <<- e$message
          NULL
        }
      )
    }

    if (!is.null(parsed_object)) {
      cli::cli_alert_success(glue::glue("{emoji_success} Data {cli::col_green('parsed to R object')} ({toupper(parse_attempt)})."))
    } else {
      fail_msg <- c(glue::glue("{emoji_fail} Failed to parse API response as {toupper(parse_attempt)}."))
      if (!is.null(parsing_error_details) && verbose) { # Only show parsing error details if verbose
        fail_msg <- c(fail_msg, glue::glue("Details: {parsing_error_details}"))
      }
      cli::cli_warn(fail_msg, .call = NULL)
    }
    return(parsed_object)
  } else { # return_format == "raw"
    cli::cli_alert_success(glue::glue("{emoji_success} Returning raw httr response object."))
    return(response)
  }
}

# Helper for default value if NULL (alternative to rlang::%||%)
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
