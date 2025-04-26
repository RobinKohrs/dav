#' Find Available Geosphere Datasets
#'
#' @description
#' Retrieves and optionally filters the list of available datasets from the
#' Geosphere API Hub based on keywords, type, or mode.
#'
#' @param url URL for the datasets endpoint. Defaults to the current v1 endpoint.
#' @param user_agent Client user agent string. Defaults to "davR".
#' @param filter_keywords Character string or vector. Keep datasets whose `title`
#'   or `description` (if available) contain any of these keywords (case-insensitive).
#' @param filter_type Character string or vector. Keep datasets matching these types
#'   (e.g., "grid", "station").
#' @param filter_mode Character string or vector. Keep datasets matching these modes
#'   (e.g., "historical", "forecast").
#' @param add_resource_id Logical. If TRUE (default), attempt to parse the `resource_id`
#'   from the dataset `url` and add it as a separate column.
#'
#' @return A data frame listing available (and potentially filtered) datasets.
#'   Includes `metadata_url` and potentially `resource_id` columns.
#'
#' @export
#' @importFrom httr GET http_type content stop_for_status user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr filter mutate select relocate any_of if_else across contains starts_with ends_with everything bind_rows
#' @importFrom stringr str_detect str_extract
#' @importFrom magrittr %>%
#' @importFrom cli cli_alert_info cli_alert_warning
#'
#' @examples
#' \dontrun{
#'   # Get all datasets
#'   all_ds = geosphere_find_datasets()
#'   print(head(all_ds))
#'
#'   # Find historical grid datasets related to temperature or radiation
#'   grid_rad_ds = geosphere_find_datasets(
#'     filter_keywords = c("temperature", "radiation", "solar"),
#'     filter_type = "grid",
#'     filter_mode = "historical"
#'   )
#'   # Display key columns for the filtered results
#'   if (nrow(grid_rad_ds) > 0) {
#'      print(grid_rad_ds[, intersect(c("resource_id", "type", "mode", "title", "url"),
#'                                    names(grid_rad_ds))])
#'   } else {
#'      print("No matching datasets found.")
#'   }
#' }
geosphere_find_datasets = function(url = "https://dataset.api.hub.geosphere.at/v1/datasets",
                                   user_agent = "davR",
                                   filter_keywords = NULL,
                                   filter_type = NULL,
                                   filter_mode = NULL,
                                   add_resource_id = TRUE) {

  # --- Request and Parse ---
  ua = httr::user_agent(user_agent)
  response = httr::GET(url, ua)
  httr::stop_for_status(response, task = "fetch Geosphere datasets list")
  if (!grepl("application/json", httr::http_type(response), ignore.case = TRUE)) {
    warning("API did not return JSON content.", call. = FALSE)
  }
  data_list = tryCatch({
    httr::content(response, as = "text", encoding = "UTF-8") %>%
      jsonlite::fromJSON(simplifyDataFrame = TRUE)
  }, error = function(e) {
    stop("Failed to parse JSON response: ", e$message, call. = FALSE)
  })

  # Use dplyr::bind_rows for robustness
  df = dplyr::bind_rows(data_list)
  if (nrow(df) == 0) {
    warning("API returned an empty list of datasets.", call. = FALSE)
    return(df) # Return empty data frame
  }

  # --- Add Derived Columns ---
  if ("url" %in% names(df)) {
    df = df %>%
      dplyr::mutate(
        metadata_url = dplyr::if_else(
          !is.na(.data$url) & nzchar(.data$url),
          paste0(.data$url, "/metadata"),
          NA_character_
        )
      ) %>%
      dplyr::relocate(dplyr::any_of("metadata_url"), .after = dplyr::any_of("url"))

    if (add_resource_id) {
      df = df %>%
        dplyr::mutate(
          resource_id = stringr::str_extract(.data$url, "[^/]+$"),
          .after = dplyr::any_of("url")
        )
    }
  } else {
    warning("Datasets list missing 'url' column, cannot add metadata_url/resource_id.")
  }


  # --- Filtering ---
  df_filtered = df # Start with the full data frame

  # Filter by Type
  if (!is.null(filter_type) && "type" %in% names(df_filtered)) {
    df_filtered = df_filtered %>%
      dplyr::filter(tolower(.data$type) %in% tolower(filter_type))
  }

  # Filter by Mode
  if (!is.null(filter_mode) && "mode" %in% names(df_filtered)) {
    df_filtered = df_filtered %>%
      dplyr::filter(tolower(.data$mode) %in% tolower(filter_mode))
  }

  # Filter by Keywords
  if (!is.null(filter_keywords)) {
    search_pattern = paste(filter_keywords, collapse = "|")
    # Identify potential text columns to search within
    text_cols_to_search = intersect(c("title", "description", "long_name", "desc"), names(df_filtered))

    if (length(text_cols_to_search) > 0) {
      df_filtered = df_filtered %>%
        dplyr::filter(
          # Apply rowSums across boolean results from str_detect on selected columns
          rowSums(
            dplyr::across(
              dplyr::all_of(text_cols_to_search),
              ~ stringr::str_detect(tolower(as.character(.x)), tolower(search_pattern))
            ), na.rm = TRUE # Sum across columns for each row
          ) > 0 # Keep row if keyword found in AT LEAST ONE column
        )
    } else {
      warning("No standard text columns (title, description, etc.) found to filter by keyword.", call. = FALSE)
    }
  }


  # --- Report Filtering Results ---
  if (nrow(df_filtered) < nrow(df)) {
    cli::cli_alert_info("Filtered datasets from {nrow(df)} down to {nrow(df_filtered)}.")
  } else if (nrow(df_filtered) == 0 && nrow(df) > 0) { # Added check if df wasn't empty initially
    cli::cli_alert_warning("Filtering resulted in zero datasets.")
  } else if (nrow(df_filtered) == nrow(df) && (!is.null(filter_keywords) || !is.null(filter_type) || !is.null(filter_mode))) {
    # If filters were applied but nothing changed
    cli::cli_alert_info("Filtering did not remove any datasets.")
  }


  return(df_filtered)
}
