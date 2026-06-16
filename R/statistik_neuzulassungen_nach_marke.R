#' Pkw-Neuzulassungen nach Marken ab Jänner 2000
#'
#' Downloads the official Statistik Austria Open Data dataset
#' *Pkw-Neuzulassungen nach Marken ab Jänner 2000* (OGD ID:
#' `OGD_fkfzul0759_OD_PkwNZL_1`) via the OGD REST API and returns a tidy
#' long tibble with one row per brand × month combination.
#'
#' The dataset covers new passenger car (Pkw) registrations in Austria by
#' brand and is updated monthly (typically around the 10th of the following
#' month). Dimension lookup CSVs are downloaded automatically on each call.
#'
#' @param date_from Date or character `"YYYY-MM"`. Keep rows from this month
#'   onward. `NULL` (default) returns the full series from January 2000.
#' @param date_to   Date or character `"YYYY-MM"`. Keep rows up to and
#'   including this month. `NULL` (default) returns all available data.
#' @param marken Character vector of brand names to keep (case-insensitive
#'   substring match against the Austrian brand label, e.g. `"VW"`,
#'   `c("BMW", "MERCEDES")`). `NULL` (default) returns all brands.
#' @param parse_date Logical. If `TRUE` (default), a `date` column of class
#'   `Date` (first day of each month) is added alongside `monat`.
#' @param verbose Logical. Print progress messages. Default `TRUE`.
#'
#' @return A `tibble` with columns:
#' \describe{
#'   \item{`monat`}{Austrian month label, e.g. `"Jänner 2000"`.}
#'   \item{`date`}{`Date`: first day of the month (only when `parse_date = TRUE`).}
#'   \item{`brand`}{Clean brand name without country code or internal code, e.g. `"VW"`.}
#'   \item{`producing_country`}{ISO vehicle registration country code of the producing country, e.g. `"D"` for Germany.}
#'   \item{`is_ev_only`}{Logical. `TRUE` if the brand sells only battery-electric vehicles (e.g. Tesla, NIO, Polestar).}
#'   \item{`marke`}{Full brand label as published by Statistik Austria, e.g. `"VW (D) <040540>"`.}
#'   \item{`anzahl`}{Integer count of new registrations.}
#' }
#'
#' @source \url{https://data.statistik.gv.at/web/meta.jsp?dataset=OGD_fkfzul0759_OD_PkwNZL_1}
#'
#' @importFrom dplyr left_join filter arrange
#' @importFrom tibble as_tibble
#' @importFrom cli cli_alert_info cli_alert_success cli_abort
#'
#' @export
#' @examples
#' \dontrun{
#' # Full series, all brands
#' statistik_neuzulassungen_nach_marke()
#'
#' # Since 2020, selected brands
#' statistik_neuzulassungen_nach_marke(
#'   date_from = "2020-01",
#'   marken    = c("VW", "SKODA", "BMW", "MERCEDES", "AUDI", "TESLA")
#' )
#'
#' # Most recent 3 months, top 10 brands by registrations
#' df <- statistik_pkw_marken_zeitreihe(date_from = Sys.Date() - 100)
#' dplyr::slice_max(df, anzahl, by = monat, n = 10)
#' }
statistik_pkw_marken_zeitreihe <- function(
  date_from  = NULL,
  date_to    = NULL,
  marken     = NULL,
  parse_date = TRUE,
  verbose    = TRUE
) {
  OGD_ID  <- "OGD_fkfzul0759_OD_PkwNZL_1"
  OGD_API <- "https://data.statistik.gv.at/ogd/json?dataset="

  # ---- 1. Fetch OGD metadata ----
  if (verbose) cli::cli_alert_info("Fetching OGD metadata for {OGD_ID}...")
  meta_txt <- tryCatch(
    readLines(paste0(OGD_API, OGD_ID), warn = FALSE, encoding = "UTF-8"),
    error = function(e) cli::cli_abort("Could not reach OGD API: {conditionMessage(e)}")
  )
  meta          <- jsonlite::fromJSON(paste(meta_txt, collapse = "\n"))
  resource_urls <- meta$resources$url
  if (verbose) cli::cli_alert_success("Found {length(resource_urls)} resource(s).")

  get_csv <- function(url) {
    read.csv(url, sep = ";", encoding = "UTF-8", stringsAsFactors = FALSE,
             na.strings = c("", "NA"))
  }

  # ---- 2. Identify resource URLs ----
  url_main   <- resource_urls[grepl(paste0(OGD_ID, "\\.csv$"), resource_urls)]
  url_brands <- resource_urls[grepl("C-J59-0", resource_urls)]
  url_months <- resource_urls[grepl("C-A10-0", resource_urls)]

  if (length(url_main) == 0 || length(url_brands) == 0 || length(url_months) == 0) {
    cli::cli_abort(
      "Could not identify expected CSV resources. The OGD API response may have changed."
    )
  }

  # ---- 3. Download CSVs ----
  if (verbose) cli::cli_alert_info("Downloading main data CSV...")
  data_raw <- get_csv(url_main)

  if (verbose) cli::cli_alert_info("Downloading dimension lookup CSVs...")
  dim_brands <- get_csv(url_brands)  # C-J59-0: Pkw-Marken
  dim_months <- get_csv(url_months)  # C-A10-0: Zeit (Monatswerte)

  # ---- 4. Build lookup tables ----
  brand_lut <- dim_brands[, c("code", "name")]
  names(brand_lut) <- c("C.J59.0", "marke")
  brand_lut$marke <- trimws(brand_lut$marke)

  month_lut <- dim_months[, c("code", "name", "en_name")]
  names(month_lut) <- c("C.A10.0", "monat", "monat_en")

  # ---- 5. Join and tidy ----
  df <- dplyr::left_join(data_raw, brand_lut, by = "C.J59.0")
  df <- dplyr::left_join(df,       month_lut, by = "C.A10.0")

  count_col <- grep("^F\\.", names(df), value = TRUE)[1]
  names(df)[names(df) == count_col] <- "anzahl"
  df$anzahl <- suppressWarnings(as.integer(df$anzahl))

  # Extract clean brand name and producing-country code from the full label.
  # Format: "BRAND NAME (CC) <NNNNNN>"  where CC = ISO country code.
  df$brand             <- trimws(sub("\\s*\\([^)]*\\).*$", "", df$marke))
  df$producing_country <- sub("^[^(]*\\(([^)]*)\\).*$", "\\1", df$marke)
  # Leave NA when the pattern didn't match (malformed labels)
  df$producing_country[!grepl("\\(", df$marke)] <- NA_character_

  # BEV-only brands (have never sold ICE or PHEV models under this brand name)
  EV_ONLY_BRANDS <- c(
    "AION",       # GAC Aion, China
    "AIWAYS",     # Aiways, China
    "LEAPMOTOR",  # Leapmotor, China
    "LEVC",       # London Electric Vehicle Company
    "LUCID",      # Lucid Motors, USA
    "MIA",        # Mia Electric, France (historic)
    "NIO",        # NIO, China
    "POLESTAR",   # Polestar, Sweden/China
    "SKYWELL",    # Skywell, China
    "TESLA",      # Tesla, USA
    "THINK",      # Think, Norway (historic)
    "TOGG",       # TOGG, Turkey
    "XPENG",      # Xpeng, China
    "ZEEKR"       # Zeekr, China
  )
  df$is_ev_only <- df$brand %in% EV_ONLY_BRANDS

  df <- df[, c("monat", "monat_en", "brand", "producing_country", "is_ev_only", "marke", "anzahl")]

  # ---- 6. Parse date ----
  if (parse_date) {
    # monat_en looks like "January 2000", "February 2026", etc.
    df$date <- as.Date(paste0("01 ", df$monat_en), format = "%d %B %Y")
    df <- df[, c("monat", "date", "brand", "producing_country", "is_ev_only", "marke", "anzahl")]
  } else {
    df$monat_en <- NULL
  }

  df <- tibble::as_tibble(df)

  # ---- 7. Filter by date ----
  if (!is.null(date_from) && parse_date) {
    from_str <- as.character(date_from)
    from <- if (grepl("^\\d{4}-\\d{2}$", from_str)) {
      as.Date(paste0(from_str, "-01"))
    } else {
      as.Date(date_from)
    }
    df <- dplyr::filter(df, date >= from)
  }
  if (!is.null(date_to) && parse_date) {
    to_str <- as.character(date_to)
    to <- if (grepl("^\\d{4}-\\d{2}$", to_str)) {
      as.Date(paste0(to_str, "-01"))
    } else {
      as.Date(date_to)
    }
    df <- dplyr::filter(df, date <= to)
  }

  # ---- 8. Filter by brand ----
  if (!is.null(marken)) {
    pattern <- paste(marken, collapse = "|")
    df <- dplyr::filter(df, grepl(pattern, brand, ignore.case = TRUE) |
                            grepl(pattern, marke, ignore.case = TRUE))
  }

  df <- dplyr::arrange(df, date, marke)

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(df)} rows | {length(unique(df$marke))} brand(s) | {length(unique(df$date))} month(s)."
    )
  }

  df
}
