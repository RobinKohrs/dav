# Ensure dependencies are listed in DESCRIPTION:
# usethis::use_package("jsonlite")
# usethis::use_package("purrr")
# usethis::use_package("glue")
# usethis::use_package("cli")
# usethis::use_package("httr")


#' Download Arctic/Antarctic Sea Ice Extent Data
#'
#' @description
#' Fetches daily sea ice extent data from the National Snow and Ice Data Center
#' (NSIDC) REST API \url{https://nsidc.org/arcticseaicenews/charctic-interactive-sea-ice-graph/}.
#' Allows specifying years, pole (North/Arctic or South/Antarctic), and optionally
#' applying a smoothing window. Also retrieves the 1981-2010 quantile data
#' (median, IQR, range) for comparison, applying the same smoothing if specified.
#'
#' @param years A numeric vector of years for which to retrieve daily data.
#' @param pole Character string: `"north"` (default) for Arctic or `"south"` for Antarctic.
#' @param window Numeric: The size of the moving average smoothing window (days).
#'   Defaults to `5`. Set `window = 1` to retrieve raw, unsmoothed data.
#'   Must be a positive integer.
#'
#' @return A tidy data frame with the following columns:
#'   * `date`: The date (as `Date` objects). For yearly data, this is the actual
#'      date. For quantile data, this is the day-of-year mapped onto the
#'      base year 2000 (a leap year) for consistent plotting.
#'   * `ice_extent_mi_sqkm`: Sea ice extent in millions of square kilometers.
#'   * `variable`: Character string indicating the data type:
#'     * The year (e.g., `"2023"`) for specific year data.
#'     * The quantile label (e.g., `"q50_1981_to_2010"`, `"q25_1981_to_2010"`)
#'       for aggregate data.
#'   * `pole`: Character string, either `"north"` or `"south"`.
#'   * `smoothing_window`: Numeric, the window size used (`1` indicates raw data).
#'
#' @export
#'
#' @importFrom jsonlite fromJSON
#' @importFrom purrr map list_rbind imap set_names
#' @importFrom glue glue
#' @importFrom cli cli_h1 cli_h2 cli_alert_info cli_alert_success cli_abort cli_warn
#' @importFrom httr GET stop_for_status content http_type http_error
#'
#' @examples
#' \dontrun{
#' # Get Arctic data for 2022 and 2023 with default 5-day smoothing
#' ice_data_arctic_smooth = fetch_sea_ice_extent(years = c(2022, 2023))
#' print(head(ice_data_arctic_smooth))
#'
#' # Get Arctic data for 2022 and 2023 with NO smoothing (raw data)
#' ice_data_arctic_raw = fetch_sea_ice_extent(years = c(2022, 2023), window = 1)
#' print(head(ice_data_arctic_raw))
#'
#' # Example of plotting (requires ggplot2, dplyr, lubridate)
#' if (requireNamespace("ggplot2", quietly = TRUE) &&
#'     requireNamespace("dplyr", quietly = TRUE) &&
#'     requireNamespace("lubridate", quietly = TRUE)) {
#'
#'   library(ggplot2)
#'   library(dplyr)
#'   library(lubridate)
#'
#'   # Plot 2023 Arctic raw data against historical raw range/median
#'   fetch_sea_ice_extent(years = 2023, pole = "north", window = 1) %>%
#'     filter(variable %in% c("2023", "q0_1981_to_2010", "q100_1981_to_2010", "q50_1981_to_2010")) %>%
#'     # Add a temporary DOY column for plotting alignment
#'     mutate(doy = yday(date)) %>%
#'     ggplot(aes(x = doy, y = ice_extent_mi_sqkm, color = variable)) +
#'     geom_line(linewidth = 1) +
#'     labs(title = "Arctic Sea Ice Extent (2023 Raw vs 1981-2010 Raw)",
#'          x = "Day of Year",
#'          y = "Ice Extent (Million sq km)",
#'          color = "Data Series") +
#'     theme_minimal()
#' }
#' }
envir_get_sea_ice_extent = function(years = NULL, pole = "north", window = 5) {

  # --- Input Validation ---
  if (is.null(years) || !is.numeric(years) || length(years) < 1) {
    cli::cli_abort("{.arg years} must be a non-empty numeric vector.")
  }
  years = as.integer(years)
  if (!is.character(pole) || length(pole) != 1 || !pole %in% c("north", "south")) {
    cli::cli_abort("{.arg pole} must be either 'north' or 'south'.")
  }
  if (!is.numeric(window) || length(window) != 1 || window < 1 || window != floor(window)) {
    cli::cli_abort("{.arg window} must be a single positive integer (use 1 for no smoothing).")
  }
  window = as.integer(window)

  # --- Constants ---
  BASE_URL = "https://nsidc.org/api/seaiceservice/extent"
  QUANTILE_BASE_YEAR = 2000 # Leap year for consistent DOY mapping

  # --- Helper Function for Robust API Fetching ---
  safe_fetch_json = function(url) {
    tryCatch({
      response = httr::GET(url)
      httr::stop_for_status(response, task = glue::glue("fetch data from {.url {url}}"))
      if (!grepl("application/json", httr::http_type(response), ignore.case = TRUE)) {
        cli::cli_abort("API did not return JSON data from {.url {url}}.", call. = FALSE)
      }
      json_content = httr::content(response, "text", encoding = "UTF-8")
      jsonlite::fromJSON(json_content)
    }, error = function(e) {
      cli::cli_abort("Failed to fetch or parse data from {.url {url}}: {e$message}", call. = FALSE)
      NULL
    })
  }

  # --- Helper Function for DOY to Date Conversion (for Quantiles) ---
  # Uses a fixed leap year as origin for consistent DOY plotting
  doy_to_date = function(doy_chr, origin_year) {
    doy_num = suppressWarnings(as.numeric(doy_chr))
    # Check if conversion worked
    if (any(is.na(doy_num))) {
      return(rep(as.Date(NA), length(doy_chr))) # Return NAs if keys weren't numeric
    }
    # NSIDC API uses day of year starting from 1. Convert to 0-based for as.Date
    as.Date(doy_num - 1, origin = glue::glue("{origin_year}-01-01"))
  }


  # --- Construct URL suffix for smoothing ---
  smoothing_suffix = if (window > 1) glue::glue("?smoothing_window={window}") else ""

  # --- Fetch Data for Specified Years ---
  cli::cli_h1("Fetching Sea Ice Extent Data")
  cli::cli_alert_info("Parameters: pole={.val {pole}}, window={.val {window}} (1=raw), years={.val {years}}")

  data_all_years = purrr::map(years, function(y) {
    cli::cli_h2(glue::glue("Fetching data for year: {y}"))
    # URL for yearly data (returns YYYY-MM-DD keys)
    url = glue::glue("{BASE_URL}/{pole}/filled_averaged_data/{y}{smoothing_suffix}")

    data_raw = safe_fetch_json(url)
    if (is.null(data_raw)) return(NULL)

    if (length(data_raw) == 0 || !is.list(data_raw) || is.null(names(data_raw))) {
      cli::cli_warn("Received empty or unexpected data structure for year {y} from {.url {url}}. Skipping.")
      return(NULL)
    }

    # Keys are expected as date strings 'YYYY-MM-DD' for yearly data
    date_keys = names(data_raw)
    ice_values = unlist(unname(data_raw))

    # Directly convert keys to Date objects
    dates = as.Date(date_keys)

    if (length(dates) != length(ice_values)) {
      cli::cli_warn("Mismatch between number of dates ({length(dates)}) and values ({length(ice_values)}) for year {y}. Skipping.")
      return(NULL)
    }
    if(any(is.na(dates))) {
      cli::cli_warn("Failed to parse some date keys (expected 'YYYY-MM-DD') for year {y}. Skipping.")
      return(NULL)
    }
    if (!is.numeric(ice_values)) {
      cli::cli_warn("Values for year {y} are not numeric. Skipping.")
      return(NULL)
    }

    df = data.frame(
      date = dates, # Actual dates for yearly data
      ice_extent_mi_sqkm = ice_values,
      variable = as.character(y),
      pole = pole,
      smoothing_window = window
    )
    cli::cli_alert_success("Successfully processed data for {y}")
    return(df)

  }, .progress = "Fetching yearly data") %>%
    purrr::list_rbind()

  # --- Fetch Interquantile Range Data ---
  cli::cli_h2("Fetching aggregate quantile data (1981-2010)")
  # URL for quantile data (returns DOY keys)
  url_quantiles = glue::glue("{BASE_URL}/{pole}/quantiles{smoothing_suffix}")
  data_quantiles_raw = safe_fetch_json(url_quantiles)

  if (is.null(data_quantiles_raw) || length(data_quantiles_raw) == 0 || !is.list(data_quantiles_raw)) {
    cli::cli_warn("Failed to fetch or received empty/unexpected quantile data from {.url {url_quantiles}}. Skipping aggregates.")
    data_aggregates = NULL
  } else {
    data_aggregates = purrr::imap(data_quantiles_raw, function(quantile_data, q_name) {

      variable_name = glue::glue("q{q_name}_1981_to_2010") # Adjust naming if needed
      cli::cli_alert_info("Processing aggregate: {variable_name} (raw name: {q_name})")

      # Validate structure
      if (!is.list(quantile_data) && !is.vector(quantile_data)) {
        cli::cli_warn("Data for aggregate '{q_name}' is not a list or vector. Skipping.")
        return(NULL)
      }
      if (length(quantile_data) == 0 || is.null(names(quantile_data))) {
        cli::cli_warn("Received empty or unnamed data structure for aggregate '{q_name}'. Skipping.")
        return(NULL)
      }

      # Keys are expected as day-of-year strings ("1"-"366") for quantiles
      doy_keys = names(quantile_data)
      ice_values = unlist(unname(quantile_data))

      # Use doy_to_date helper function for conversion
      dates = doy_to_date(doy_keys, QUANTILE_BASE_YEAR)

      # Check if date conversion failed (e.g., non-numeric keys)
      if (any(is.na(dates))) {
        bad_keys = head(doy_keys[is.na(suppressWarnings(as.numeric(doy_keys)))])
        cli::cli_warn("Failed to parse some day-of-year keys (expected '1'-'366') for aggregate '{q_name}'. Skipping. Problematic examples: {bad_keys}")
        return(NULL)
      }

      # Check value consistency
      if (length(dates) != length(ice_values)) {
        cli::cli_warn("Mismatch between number of valid dates ({length(dates)}) and values ({length(ice_values)}) for aggregate '{q_name}'. Skipping.")
        return(NULL)
      }
      if (!is.numeric(ice_values)) {
        cli::cli_warn("Values for aggregate '{q_name}' are not numeric. Skipping.")
        return(NULL)
      }

      # --- Create DataFrame ---
      df <- tibble::tibble(
        date = dates, # Dates mapped onto QUANTILE_BASE_YEAR (2000) - Length 366
        ice_extent_mi_sqkm = ice_values, # Length 366
        variable = variable_name,       # Length 1 - tibble recycles this
        pole = pole,                    # Length 1 - tibble recycles this
        smoothing_window = window       # Length 1 - tibble recycles this
      )
      return(df)

    }) %>%
      purrr::list_rbind()
  }

  # --- Combine Datasets ---
  final_data = purrr::list_rbind(list(data_all_years, data_aggregates))

  if (is.null(final_data) || nrow(final_data) == 0) {
    cli::cli_warn("No data successfully retrieved or processed.")
    return(
      data.frame(
        date = as.Date(character(0)),
        ice_extent_mi_sqkm = numeric(0),
        variable = character(0),
        pole = character(0),
        smoothing_window = integer(0)
      )
    )
  }

  cli::cli_h1("Finished")
  cli::cli_alert_success("Returning combined data frame with {nrow(final_data)} rows.")
  return(final_data)
}
