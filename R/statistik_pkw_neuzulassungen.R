#' Get Pkw-Neuzulassungen by Brand since January 2000
#'
#' Downloads the official Statistik Austria Open Data dataset
#' *Pkw-Neuzulassungen nach Marken ab Jänner 2000* via the OGD REST API.
#' Returns a tidy long tibble with one row per brand × month combination.
#'
#' The dataset is updated monthly (typically around the 10th of the following
#' month). The OGD endpoint is queried fresh each call; the dimension lookup
#' CSVs are small and downloaded automatically.
#'
#' @param date_from Date or character `"YYYY-MM"`. Keep rows from this month
#'   onward. `NULL` (default) returns the full series from January 2000.
#' @param date_to   Date or character `"YYYY-MM"`. Keep rows up to and
#'   including this month. `NULL` (default) returns all available data.
#' @param brands Character vector of brand names to keep (case-insensitive
#'   substring match against the Austrian brand label, e.g. `"VW"`,
#'   `c("BMW", "MERCEDES")`). `NULL` (default) returns all brands.
#' @param parse_date Logical. If `TRUE` (default), a `date` column of class
#'   `Date` (first day of each month) is added alongside `monat`.
#' @param verbose Logical. Print progress messages.
#'
#' @return A `tibble` with columns:
#' \describe{
#'   \item{`monat`}{Austrian month label, e.g. `"Jänner 2000"`.}
#'   \item{`date`}{`Date`: first day of the month (if `parse_date = TRUE`).}
#'   \item{`marke`}{Brand name, e.g. `"VW (D)"`.}
#'   \item{`anzahl`}{Integer count of new registrations.}
#' }
#'
#' @importFrom httr GET content status_code
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr left_join select filter rename mutate arrange
#' @importFrom cli cli_alert_info cli_alert_success cli_abort
#'
#' @export
#' @examples
#' \dontrun{
#' # Full series, all brands
#' statistik_get_pkw_neuzulassungen()
#'
#' # Since 2020, Pkw brands of interest
#' statistik_get_pkw_neuzulassungen(
#'   date_from = "2020-01",
#'   brands    = c("VW", "SKODA", "BMW", "MERCEDES", "AUDI", "TESLA")
#' )
#'
#' # Quick look: latest 3 months, top brands
#' df <- statistik_get_pkw_neuzulassungen(date_from = Sys.Date() - 100)
#' dplyr::slice_max(df, anzahl, by = monat, n = 10)
#' }
statistik_get_pkw_neuzulassungen <- function(
  date_from  = NULL,
  date_to    = NULL,
  brands     = NULL,
  parse_date = TRUE,
  verbose    = TRUE
) {
  OGD_ID  <- "OGD_fkfzul0759_OD_PkwNZL_1"
  OGD_API <- "https://data.statistik.gv.at/ogd/json?dataset="
  OGD_DATA <- "https://data.statistik.gv.at/data/"

  # ---- 1. Fetch metadata to confirm URLs ----
  if (verbose) cli::cli_alert_info("Fetching OGD metadata for {OGD_ID}...")
  meta_txt <- tryCatch(
    readLines(paste0(OGD_API, OGD_ID), warn = FALSE, encoding = "UTF-8"),
    error = function(e) cli::cli_abort("Could not reach OGD API: {conditionMessage(e)}")
  )
  meta <- jsonlite::fromJSON(paste(meta_txt, collapse = "\n"))
  resource_urls <- meta$resources$url
  if (verbose) cli::cli_alert_success("Found {length(resource_urls)} resource(s)")

  get_csv <- function(url) {
    read.csv(url, sep = ";", encoding = "UTF-8", stringsAsFactors = FALSE,
             na.strings = c("", "NA"))
  }

  # ---- 2. Download dimension lookup tables ----
  url_main   <- resource_urls[grepl(paste0(OGD_ID, "\\.csv$"), resource_urls)]
  url_brands <- resource_urls[grepl("C-J59-0", resource_urls)]
  url_months <- resource_urls[grepl("C-A10-0", resource_urls)]

  if (length(url_main) == 0 || length(url_brands) == 0 || length(url_months) == 0) {
    cli::cli_abort("Could not identify expected CSV resources. The API response may have changed.")
  }

  if (verbose) cli::cli_alert_info("Downloading main data CSV...")
  data_raw <- get_csv(url_main)

  if (verbose) cli::cli_alert_info("Downloading dimension lookup CSVs...")
  dim_brands <- get_csv(url_brands)  # J59: brand codes
  dim_months <- get_csv(url_months)  # A10: month codes

  # ---- 3. Build lookup tables ----
  brand_lut <- dim_brands[, c("code", "name")]
  names(brand_lut) <- c("C.J59.0", "marke")
  brand_lut$marke <- trimws(brand_lut$marke)

  month_lut <- dim_months[, c("code", "name", "en_name")]
  names(month_lut) <- c("C.A10.0", "monat", "monat_en")

  # ---- 4. Join and tidy ----
  df <- dplyr::left_join(data_raw,  brand_lut, by = "C.J59.0")
  df <- dplyr::left_join(df, month_lut, by = "C.A10.0")

  # Rename count column
  count_col <- grep("^F\\.", names(df), value = TRUE)[1]
  names(df)[names(df) == count_col] <- "anzahl"

  df <- df[, c("monat", "monat_en", "marke", "anzahl")]
  df$anzahl <- suppressWarnings(as.integer(df$anzahl))

  # ---- 5. Parse date from month code ----
  if (parse_date) {
    # monat_en looks like "January 2000", "February 2026" etc.
    df$date <- as.Date(paste0("01 ", df$monat_en), format = "%d %B %Y")
    df <- df[, c("monat", "date", "marke", "anzahl")]
  } else {
    df$monat_en <- NULL
  }

  df <- tibble::as_tibble(df)

  # ---- 6. Filter by date ----
  if (!is.null(date_from) && parse_date) {
    from <- as.Date(paste0(as.character(date_from), "-01"))
    if (!grepl("-", as.character(date_from))) {
      from <- as.Date(date_from)
    }
    df <- dplyr::filter(df, date >= from)
  }
  if (!is.null(date_to) && parse_date) {
    to <- as.Date(paste0(as.character(date_to), "-01"))
    if (!grepl("-", as.character(date_to))) {
      to <- as.Date(date_to)
    }
    df <- dplyr::filter(df, date <= to)
  }

  # ---- 7. Filter by brand ----
  if (!is.null(brands)) {
    pattern <- paste(brands, collapse = "|")
    df <- dplyr::filter(df, grepl(pattern, marke, ignore.case = TRUE))
  }

  df <- dplyr::arrange(df, date, marke)

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(df)} rows | {length(unique(df$marke))} brand(s) | {length(unique(df$date))} month(s)"
    )
  }
  df
}
