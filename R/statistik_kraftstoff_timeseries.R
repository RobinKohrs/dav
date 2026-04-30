#' Get a Complete Pkw-Neuzulassungen Time Series by Bundesland and Kraftstoffart
#'
#' Combines the bundled historical dataset (2006–2025, from a Statistik Austria
#' special evaluation) with freshly downloaded current-year data from the
#' Statistik Austria website. The current-year ODS URL changes every month as
#' new data is published — the function always discovers it dynamically.
#'
#' **Coverage:**
#' * 2006-01 to 2025-12: bundled historical data (offline, instant)
#' * current year (Jan onwards): downloaded live from Statistik Austria
#'
#' **Note:** The historical data covers only Bundesland-level PKW totals across
#' all vehicle categories. The current-year ODS also contains per-vehicle-type
#' breakdowns, but this function filters to the same Bundesland totals for a
#' consistent series.
#'
#' @param date_from Character `"YYYY-MM"` or `Date`. Keep rows from this month.
#'   Default: `NULL` (all data from 2006-01).
#' @param date_to   Character `"YYYY-MM"` or `Date`. Keep rows up to this month.
#'   Default: `NULL` (all available data including current year).
#' @param bundesland Character vector of Bundesland names to keep, e.g.
#'   `c("Wien", "Tirol")`. `"Österreich"` is the national total. `NULL`
#'   (default) returns all states.
#' @param kraftstoffart Character vector of fuel types to keep, e.g.
#'   `c("Elektro", "Diesel")`. `NULL` (default) returns all fuel types.
#' @param include_current_year Logical. If `TRUE` (default), downloads and
#'   appends the current-year data from Statistik Austria. Set to `FALSE` to
#'   return only the bundled historical data.
#' @param verbose Logical. Print progress messages.
#' @param page_url The Statistik Austria page URL used to discover the current
#'   ODS file.
#'
#' @return A `tibble` with columns:
#' \describe{
#'   \item{`bundesland`}{State name or `"Österreich"` for national total.}
#'   \item{`kraftstoffart`}{Fuel/drive type.}
#'   \item{`year`}{Integer year.}
#'   \item{`month`}{Integer month (1–12).}
#'   \item{`date`}{`Date`: first day of the month.}
#'   \item{`anzahl`}{Integer count of new registrations.}
#' }
#'
#' @seealso [at_pkw_kraftstoff_hist] for the bundled historical dataset,
#'   [statistik_get_kfz_neuzulassungen()] for richer current-year breakdowns.
#'
#' @importFrom dplyr bind_rows filter mutate arrange if_else
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_abort
#' @importFrom httr GET write_disk status_code
#' @importFrom readODS list_ods_sheets read_ods
#' @importFrom tidyr pivot_longer
#'
#' @export
#' @examples
#' \dontrun{
#' # Full series, all Bundesländer, all fuel types
#' statistik_get_kraftstoff_timeseries()
#'
#' # Elektro only, Vienna + national total
#' statistik_get_kraftstoff_timeseries(
#'   bundesland   = c("Wien", "Österreich"),
#'   kraftstoffart = "Elektro"
#' )
#'
#' # Since 2020
#' statistik_get_kraftstoff_timeseries(date_from = "2020-01")
#' }
statistik_get_kraftstoff_timeseries <- function(
  date_from            = NULL,
  date_to              = NULL,
  bundesland           = NULL,
  kraftstoffart        = NULL,
  include_current_year = TRUE,
  verbose              = TRUE,
  page_url             = "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen"
) {
  MONTH_NUM <- c(
    "Jänner" = 1L, "Februar" = 2L, "März" = 3L, "April" = 4L,
    "Mai" = 5L, "Juni" = 6L, "Juli" = 7L, "August" = 8L,
    "September" = 9L, "Oktober" = 10L, "November" = 11L, "Dezember" = 12L
  )
  VALID_MONTHS <- names(MONTH_NUM)

  # ---- 1. Load bundled historical data ----
  if (verbose) cli::cli_alert_info("Loading bundled historical data (2006–2025)...")
  hist <- at_pkw_kraftstoff_hist
  if (verbose) cli::cli_alert_success("{nrow(hist)} historical rows ({min(hist$date)} – {max(hist$date)})")

  # ---- 2. Download current-year data ----
  current_data <- NULL

  if (include_current_year) {
    current_year <- as.integer(format(Sys.Date(), "%Y"))

    if (verbose) cli::cli_alert_info("Fetching current-year ({current_year}) ODS from Statistik Austria...")

    raw_lines <- tryCatch(
      readLines(page_url, warn = FALSE, encoding = "UTF-8"),
      error = function(e) {
        cli::cli_alert_warning("Could not reach Statistik Austria page: {conditionMessage(e)}")
        return(NULL)
      }
    )

    if (!is.null(raw_lines)) {
      all_paths <- unique(unlist(regmatches(
        raw_lines,
        gregexpr('/fileadmin/pages/77/[^"]+\\.ods', raw_lines)
      )))

      # DE3 = Bundesland × Kraftstoffart (monthly sheets for current year)
      de3_path <- grep("DE3_", all_paths, value = TRUE)

      if (length(de3_path) == 0) {
        cli::cli_alert_warning("Could not find DE3 ODS file on page. Skipping current-year data.")
      } else {
        file_url <- paste0("https://www.statistik.at", de3_path[1])
        if (verbose) cli::cli_alert_info("Using: {.url {file_url}}")

        tmp_ods <- tempfile(fileext = ".ods")
        resp <- tryCatch(
          httr::GET(file_url, httr::write_disk(tmp_ods, overwrite = TRUE)),
          error = function(e) {
            cli::cli_alert_warning("Download failed: {conditionMessage(e)}")
            return(NULL)
          }
        )

        if (!is.null(resp) && httr::status_code(resp) == 200) {
          if (verbose) cli::cli_alert_success("Downloaded ({round(file.size(tmp_ods)/1024)} KB)")

          sheets_all   <- readODS::list_ods_sheets(tmp_ods)
          month_sheets <- sheets_all[sheets_all %in% VALID_MONTHS]

          parse_de3_sheet <- function(sheet_name) {
            raw <- suppressMessages(
              readODS::read_ods(tmp_ods, sheet = sheet_name, col_names = FALSE)
            )
            # Row 2: fuel type headers
            fuel_types <- trimws(as.character(unlist(raw[2, -1])))

            data_rows <- raw[3:nrow(raw), ]
            # Keep only Bundesland-level rows (the regional total rows)
            bl_labels <- c(
              "Österreich", "Burgenland", "Kärnten", "Niederösterreich",
              "Oberösterreich", "Salzburg", "Steiermark", "Tirol",
              "Vorarlberg", "Wien"
            )
            bl_rows <- trimws(as.character(data_rows[[1]])) %in% bl_labels
            data_rows <- data_rows[bl_rows, ]

            if (nrow(data_rows) == 0) return(NULL)

            result_rows <- lapply(seq_len(nrow(data_rows)), function(i) {
              bl   <- trimws(as.character(data_rows[i, 1]))
              vals <- as.character(unlist(data_rows[i, -1]))
              # align vals to fuel_types
              n <- min(length(vals), length(fuel_types))
              data.frame(
                bundesland    = bl,
                kraftstoffart = fuel_types[seq_len(n)],
                anzahl_raw    = vals[seq_len(n)],
                stringsAsFactors = FALSE
              )
            })

            res <- do.call(rbind, result_rows)
            res$monat <- sheet_name
            res
          }

          sheets_parsed <- lapply(month_sheets, parse_de3_sheet)
          sheets_parsed <- Filter(Negate(is.null), sheets_parsed)

          if (length(sheets_parsed) > 0) {
            cur_raw <- do.call(rbind, sheets_parsed)
            current_data <- tibble::as_tibble(cur_raw) |>
              dplyr::mutate(
                year   = current_year,
                month  = MONTH_NUM[monat],
                date   = as.Date(sprintf("%d-%02d-01", year, month)),
                anzahl = suppressWarnings(as.integer(dplyr::case_when(
                  trimws(anzahl_raw) == "-" ~ "0",
                  trimws(anzahl_raw) == "/" ~ NA_character_,
                  TRUE                      ~ gsub("[^0-9]", "", anzahl_raw)
                )))
              ) |>
              dplyr::filter(!is.na(month), nzchar(bundesland)) |>
              dplyr::select(bundesland, kraftstoffart, year, month, date, anzahl)

            if (verbose) {
              cli::cli_alert_success(
                "{nrow(current_data)} current-year rows ({length(month_sheets)} month(s))"
              )
            }
          }
        }
      }
    }
  }

  # ---- 3. Combine ----
  out <- if (!is.null(current_data)) {
    # Remove any historical rows that overlap with current year (avoid duplicates)
    hist_trimmed <- dplyr::filter(hist, year < as.integer(format(Sys.Date(), "%Y")))
    dplyr::bind_rows(hist_trimmed, current_data)
  } else {
    hist
  }

  out <- dplyr::arrange(out, bundesland, kraftstoffart, date)

  # ---- 4. Filter ----
  as_date_from <- function(x) {
    if (is.null(x)) return(NULL)
    if (inherits(x, "Date")) return(x)
    as.Date(paste0(x, "-01"))
  }
  df <- as_date_from(date_from)
  dt <- as_date_from(date_to)

  if (!is.null(df)) out <- dplyr::filter(out, date >= df)
  if (!is.null(dt)) out <- dplyr::filter(out, date <= dt)

  if (!is.null(bundesland)) {
    out <- dplyr::filter(out, bundesland %in% bundesland)
  }
  if (!is.null(kraftstoffart)) {
    out <- dplyr::filter(out, kraftstoffart %in% kraftstoffart)
  }

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(out)} rows | {length(unique(out$bundesland))} state(s) | {length(unique(out$kraftstoffart))} fuel type(s) | {min(out$date)} – {max(out$date)}"
    )
  }

  tibble::as_tibble(out)
}
