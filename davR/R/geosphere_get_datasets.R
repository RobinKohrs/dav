#' Get Available Geosphere Datasets
#'
#' Retrieves a list of available datasets from the Geosphere API Hub.
#'
#' @description
#' Fetches metadata about datasets available through the Geosphere API.
#' This provides similar information to exploring the datasets section of the
#' API documentation: \url{https://dataset.api.hub.geosphere.at/v1/docs/}
#'
#' @param url The URL for the datasets endpoint. Defaults to the current v1 endpoint.
#' @param user_agent A string to identify the client (e.g., your package name and version).
#'        Defaults to "my_geosphere_r_package (github.com/your_repo)". Please customize.
#'
#' @return A data frame listing available datasets. The exact columns depend on the
#'   API response, but typically include identifiers, descriptions, and URLs.
#'   This function adds a `metadata_url` column pointing to the specific metadata
#'   endpoint for each dataset (derived from the dataset's `url` returned by the API).
#'
#' @details
#' The API response structure is expected to be a JSON array of dataset objects.
#' Each object should ideally contain at least a `url` field from which the
#' `metadata_url` can be derived.
#'
#' For details on the specific *parameters* available for querying individual
#' grid datasets, refer to the API documentation, for example:
#' \url{https://dataset.api.hub.geosphere.at/v1/openapi-docs#/grid/Historical_Grid_Data_grid_historical__resource_id__get}
#'
#' @export
#' @importFrom httr GET http_type status_code content stop_for_status user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows mutate select relocate any_of if_else
#' @importFrom glue glue
#' @importFrom magrittr %>%
#'
#' @examples
#' \dontrun{
#'   try({
#'     datasets_df = geosphere_get_datasets()
#'     print(head(datasets_df))
#'     # Example of accessing metadata for the first dataset (if 'metadata_url' exists)
#'     if ("metadata_url" %in% names(datasets_df) && nrow(datasets_df) > 0) {
#'       # metadata_content = httr::content(httr::GET(datasets_df$metadata_url[1]))
#'       # print(metadata_content)
#'     }
#'   })
#' }
geosphere_get_datasets = function(url = "https://dataset.api.hub.geosphere.at/v1/datasets",
                                  user_agent = "davR") {

  # --- 1. Input Validation (Basic) ---
  if (!is.character(url) || length(url) != 1 || !startsWith(url, "http")) {
    stop("'url' must be a single valid HTTP/HTTPS URL string.", call. = FALSE)
  }
  if (!is.character(user_agent) || length(user_agent) != 1 || nchar(user_agent) == 0) {
    stop("'user_agent' must be a non-empty string.", call. = FALSE)
  }

  # --- 2. Perform HTTP GET Request ---
  ua = httr::user_agent(user_agent)
  response = httr::GET(url, ua)

  # --- 3. Check HTTP Status ---
  httr::stop_for_status(response, task = "fetch Geosphere datasets list")

  # --- 4. Check Content Type ---
  if (!httr::http_type(response) == "application/json") {
    warning("API did not return JSON content as expected. Content type was: ",
            httr::http_type(response), call. = FALSE)
  }

  # --- 5. Parse JSON Response ---
  data_list = tryCatch({
    httr::content(response, as = "text", encoding = "UTF-8") %>%
      jsonlite::fromJSON(simplifyDataFrame = TRUE)
  },
  error = function(e) {
    stop("Failed to parse JSON response: ", e$message, call. = FALSE)
  }
  )

  # --- 6. Convert to Data Frame (if needed) ---
  if (is.list(data_list) && !is.data.frame(data_list)) {
    df = dplyr::bind_rows(data_list)
    if (nrow(df) == 0 && length(data_list) > 0) {
      warning("Could not convert the list structure to a data frame effectively using bind_rows.")
    }
  } else if (is.data.frame(data_list)) {
    df = data_list
  } else {
    stop("Parsed JSON content could not be interpreted as a list or data frame.", call. = FALSE)
  }

  if (nrow(df) == 0) {
    warning("API returned an empty list of datasets.", call. = FALSE)
    if ("url" %in% names(df)) {
      df$metadata_url = character(0)
    }
    return(df)
  }


  # --- 7. Add Derived Columns ---
  if (!"url" %in% names(df)) {
    warning("API response data frame is missing the expected 'url' column. ",
            "Cannot generate 'metadata_url'.", call. = FALSE)
    df$metadata_url = NA_character_
  } else {
    df = df %>%
      dplyr::mutate(
        metadata_url = dplyr::if_else(
          !is.na(.data$url) & nzchar(.data$url),
          glue::glue("{.data$url}/metadata"),
          NA_character_
        )
      ) %>%
      dplyr::relocate(dplyr::any_of("metadata_url"), .after = dplyr::any_of("url"))
  }

  # --- 8. Return Data Frame ---
  return(df)
}
