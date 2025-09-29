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
geosphere_get_datasets = function(
  url = "https://dataset.api.hub.geosphere.at/v1/datasets",
  user_agent = "davR",
  filter_keywords = NULL,
  filter_type = NULL,
  filter_mode = NULL,
  add_resource_id = TRUE
) {
  # --- Request and Parse ---
  ua = httr::user_agent(user_agent)
  response = httr::GET(url, ua)
  httr::stop_for_status(response, task = "fetch Geosphere datasets list")
  if (
    !grepl("application/json", httr::http_type(response), ignore.case = TRUE)
  ) {
    warning("API did not return JSON content.", call. = FALSE)
  }
  data_list = tryCatch(
    {
      httr::content(response, as = "text", encoding = "UTF-8") %>%
        jsonlite::fromJSON(simplifyDataFrame = TRUE)
    },
    error = function(e) {
      stop("Failed to parse JSON response: ", e$message, call. = FALSE)
    }
  )

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
      dplyr::relocate(
        dplyr::any_of("metadata_url"),
        .after = dplyr::any_of("url")
      )

    if (add_resource_id) {
      df = df %>%
        dplyr::mutate(
          resource_id = stringr::str_extract(.data$url, "[^/]+$"),
          .after = dplyr::any_of("url")
        )
    }
  } else {
    warning(
      "Datasets list missing 'url' column, cannot add metadata_url/resource_id."
    )
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
    text_cols_to_search = intersect(
      c("title", "description", "long_name", "desc"),
      names(df_filtered)
    )

    if (length(text_cols_to_search) > 0) {
      df_filtered = df_filtered %>%
        dplyr::filter(
          # Apply rowSums across boolean results from str_detect on selected columns
          rowSums(
            dplyr::across(
              dplyr::all_of(text_cols_to_search),
              ~ stringr::str_detect(
                tolower(as.character(.x)),
                tolower(search_pattern)
              )
            ),
            na.rm = TRUE # Sum across columns for each row
          ) >
            0 # Keep row if keyword found in AT LEAST ONE column
        )
    } else {
      warning(
        "No standard text columns (title, description, etc.) found to filter by keyword.",
        call. = FALSE
      )
    }
  }

  # --- Report Filtering Results ---
  if (nrow(df_filtered) < nrow(df)) {
    cli::cli_alert_info(
      "Filtered datasets from {nrow(df)} down to {nrow(df_filtered)}."
    )
  } else if (nrow(df_filtered) == 0 && nrow(df) > 0) {
    # Added check if df wasn't empty initially
    cli::cli_alert_warning("Filtering resulted in zero datasets.")
  } else if (
    nrow(df_filtered) == nrow(df) &&
      (!is.null(filter_keywords) ||
        !is.null(filter_type) ||
        !is.null(filter_mode))
  ) {
    # If filters were applied but nothing changed
    cli::cli_alert_info("Filtering did not remove any datasets.")
  }

  return(df_filtered)
}

#' @rdname geosphere_get_datasets
#' @export
geosphere_find_datasets <- geosphere_get_datasets

#' Get Available Parameters for a Geosphere Resource
#'
#' @description
#' Retrieves all available parameters for a specific Geosphere resource ID
#' and returns them as a clean dataframe. The function automatically determines
#' the correct type/mode combination for the resource.
#'
#' @param resource_id Character string. The specific dataset or resource ID
#'   (e.g., "klima-v2-1d", "klima-v2-10min").
#' @param type Character string or `NULL`. The data type (e.g., "grid", "station").
#'   If `NULL` (default), the function will try to auto-detect it.
#' @param mode Character string or `NULL`. The data mode (e.g., "historical").
#'   If `NULL` (default), the function will try to auto-detect it.
#' @param api_url Base URL for the Geosphere API. Defaults to Geosphere Hub v1.
#' @param version API version string. Defaults to "v1".
#' @param user_agent A string to identify the client. Defaults to "davR".
#'
#' @return A data frame (tibble) containing all available parameters with columns:
#'   \item{name}{Parameter short name/code}
#'   \item{long_name}{Descriptive parameter name}
#'   \item{description}{Detailed parameter description}
#'   \item{unit}{Measurement unit}
#'   \item{code_list_ref}{Reference to code list (if applicable)}
#'   Returns `NULL` if the resource is not found or metadata cannot be retrieved.
#'
#' @export
#' @importFrom httr GET modify_url content stop_for_status user_agent http_type
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_alert_info cli_alert_warning cli_alert_danger
#' @importFrom dplyr filter distinct select mutate any_of
#' @importFrom tibble as_tibble
#'
#' @examples
#' \dontrun{
#'   # Get parameters for daily climate data
#'   params_daily <- geosphere_get_available_resource_parameters("klima-v2-1d")
#'   print(head(params_daily))
#'
#'   # Get parameters for 10-minute climate data
#'   params_10min <- geosphere_get_available_resource_parameters("klima-v2-10min")
#'
#'   # Specify type and mode explicitly if auto-detection fails
#'   params_explicit <- geosphere_get_available_resource_parameters(
#'     "klima-v2-1d",
#'     type = "station",
#'     mode = "historical"
#'   )
#' }
geosphere_get_available_resource_parameters <- function(
  resource_id,
  type = NULL,
  mode = NULL,
  api_url = "https://dataset.api.hub.geosphere.at",
  version = "v1",
  user_agent = "davR"
) {
  # --- 1. Input Validation ---
  if (
    missing(resource_id) ||
      !is.character(resource_id) ||
      length(resource_id) != 1 ||
      nchar(trimws(resource_id)) == 0
  ) {
    stop(
      "`resource_id` is required and must be a non-empty string.",
      call. = FALSE
    )
  }
  resource_id <- trimws(resource_id)

  # --- 2. Auto-detect type/mode if not provided ---
  if (is.null(type) || is.null(mode)) {
    cli::cli_alert_info(
      "Auto-detecting type/mode for resource ID: {.val {resource_id}}"
    )

    # Use geosphere_get_datasets to find the resource
    all_datasets <- tryCatch(
      geosphere_get_datasets(add_resource_id = TRUE, user_agent = user_agent),
      error = function(e) {
        cli::cli_alert_warning(
          "Failed to retrieve dataset list for auto-detection: {e$message}"
        )
        return(NULL)
      }
    )

    if (!is.null(all_datasets) && "resource_id" %in% names(all_datasets)) {
      matching_datasets <- dplyr::filter(
        all_datasets,
        .data$resource_id == !!resource_id
      )

      if (nrow(matching_datasets) > 0) {
        # Get first available combination
        type <- matching_datasets$type[1]
        mode <- matching_datasets$mode[1]
        cli::cli_alert_info(
          "Auto-detected: type={.val {type}}, mode={.val {mode}}"
        )
      } else {
        cli::cli_alert_warning(
          "Resource ID not found in datasets list. Trying common defaults..."
        )
      }
    }

    # Fallback to common combinations if auto-detection failed
    if (is.null(type) || is.null(mode)) {
      type <- "station"
      mode <- "historical"
      cli::cli_alert_info(
        "Using fallback: type={.val {type}}, mode={.val {mode}}"
      )
    }
  }

  # --- 3. Construct metadata URL and fetch data ---
  metadata_path <- paste(
    version,
    type,
    mode,
    resource_id,
    "metadata",
    sep = "/"
  )
  metadata_url <- httr::modify_url(api_url, path = metadata_path)
  ua <- httr::user_agent(user_agent)

  cli::cli_alert_info("Fetching parameters from: {.url {metadata_url}}")

  metadata <- tryCatch(
    {
      response <- httr::GET(metadata_url, ua)
      httr::stop_for_status(
        response,
        task = paste("fetch metadata for", resource_id)
      )

      if (
        !grepl(
          "application/json",
          httr::http_type(response),
          ignore.case = TRUE
        )
      ) {
        warning("API did not return JSON content as expected.", call. = FALSE)
      }

      response_text <- httr::content(response, as = "text", encoding = "UTF-8")
      if (!nzchar(response_text)) {
        stop(
          "Received empty response body from metadata endpoint.",
          call. = FALSE
        )
      }

      jsonlite::fromJSON(response_text, simplifyVector = TRUE)
    },
    error = function(e) {
      cli::cli_alert_danger("Failed to fetch metadata: {e$message}")
      return(NULL)
    }
  )

  if (is.null(metadata)) {
    return(NULL)
  }

  # --- 4. Extract and format parameters ---
  if (is.null(metadata$parameters) || length(metadata$parameters) == 0) {
    cli::cli_alert_warning(
      "No parameters found in metadata for resource {.val {resource_id}}"
    )
    return(NULL)
  }

  # Convert parameters to dataframe
  params_df <- tryCatch(
    {
      if (is.data.frame(metadata$parameters)) {
        tibble::as_tibble(metadata$parameters)
      } else if (is.list(metadata$parameters)) {
        # Handle case where parameters might be a list of lists
        dplyr::bind_rows(metadata$parameters) %>% tibble::as_tibble()
      } else {
        stop("Unexpected parameters format in metadata")
      }
    },
    error = function(e) {
      cli::cli_alert_danger("Failed to process parameters data: {e$message}")
      return(NULL)
    }
  )

  if (is.null(params_df) || nrow(params_df) == 0) {
    cli::cli_alert_warning("No parameters could be extracted from metadata")
    return(NULL)
  }

  # --- 5. Clean and standardize column names ---
  # Ensure we have the most important columns, fill missing ones with NA
  expected_cols <- c(
    "name",
    "long_name",
    "description",
    "unit",
    "code_list_ref"
  )
  missing_cols <- setdiff(expected_cols, names(params_df))

  # Add missing columns as NA
  for (col in missing_cols) {
    params_df[[col]] <- NA_character_
  }

  # Select and reorder columns
  params_df <- params_df %>%
    dplyr::select(dplyr::any_of(expected_cols), dplyr::everything()) %>%
    dplyr::distinct()

  cli::cli_alert_info(
    "Successfully extracted {nrow(params_df)} parameters for resource {.val {resource_id}}"
  )

  return(params_df)
}
