# Known Austrian Bundesländer (used to detect hierarchy in DE3/annual files)
.BUNDESLAENDER_AT <- c(
  "Österreich", "Burgenland", "Kärnten", "Niederösterreich",
  "Oberösterreich", "Salzburg", "Steiermark", "Tirol", "Vorarlberg", "Wien"
)

#' Get Kfz-Neuzulassungen Data from Statistik Austria
#'
#' Downloads and parses Kfz-Neuzulassungen data from the Statistik Austria
#' website. The source ODS file URL changes every month as new data is
#' published — the function always discovers the current URL dynamically from
#' the page so no manual link maintenance is needed.
#'
#' Two data types are available:
#' \describe{
#'   \item{`"kraftstoff"`}{Neuzulassungen by fuel/energy type, vehicle type,
#'     and Bundesland. Current year returns monthly sheets; historical years
#'     return annual totals.
#'     Columns: `monat`, `bundesland`, `fahrzeugtyp`, `kraftstoffart`, `anzahl`.}
#'   \item{`"marken"`}{Neuzulassungen by brand and vehicle type.
#'     Current year only (monthly sheets).
#'     Columns: `monat`, `marke`, `fahrzeugtyp`, `anzahl`.
#'     For PKW brand data since January 2000 use
#'     [statistik_get_pkw_neuzulassungen()].}
#' }
#'
#' @param type Character. One of `"kraftstoff"` (default) or `"marken"`.
#' @param year Integer scalar. The year to retrieve. `NULL` (default) uses the
#'   current year (monthly sheets). For `type = "kraftstoff"` you can also
#'   pass a past year, e.g. `2024` or `2025`, to get the corresponding annual
#'   ODS file. Historical files are only available for years listed on the
#'   Statistik Austria page (currently 2024–2025 for the Kraftstoff breakdown).
#' @param months Character vector of month sheet names to include, e.g.
#'   `c("Jänner", "Februar")`. `NULL` (default) returns all available sheets.
#'   Ignored when `year` refers to a historical annual file.
#' @param suppress_as_na Logical. If `TRUE` (default), suppressed cells
#'   (`"/"` in source, meaning n < 5) become `NA`. If `FALSE` they become `0`.
#' @param verbose Logical. Print progress messages.
#' @param page_url The Statistik Austria page to discover ODS links from.
#'
#' @return A `tibble` in long format. All counts are integer.
#'
#' @importFrom readODS list_ods_sheets read_ods
#' @importFrom tidyr pivot_longer
#' @importFrom dplyr bind_rows case_when
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_abort
#' @importFrom httr GET write_disk status_code
#'
#' @export
#' @examples
#' \dontrun{
#' # Current year: monthly Elektro/Diesel/... breakdown per Bundesland
#' statistik_get_kfz_neuzulassungen("kraftstoff")
#'
#' # Only Jänner and Februar, filtered to PKW and Wien
#' df <- statistik_get_kfz_neuzulassungen("kraftstoff", months = c("Jänner", "Februar"))
#' df[df$bundesland == "Wien" & df$fahrzeugtyp == "Personenkraftwagen Klasse M1", ]
#'
#' # Historical annual Kraftstoff breakdown for 2025
#' statistik_get_kfz_neuzulassungen("kraftstoff", year = 2025)
#'
#' # Current year: monthly brand × vehicle type
#' statistik_get_kfz_neuzulassungen("marken")
#'
#' # For PKW brand data since 2000, use the OGD function:
#' statistik_get_pkw_neuzulassungen(date_from = "2020-01")
#' }
statistik_get_kfz_neuzulassungen <- function(
  type           = c("kraftstoff", "marken"),
  year           = NULL,
  months         = NULL,
  suppress_as_na = TRUE,
  verbose        = TRUE,
  page_url       = "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen"
) {
  type <- match.arg(type)
  base_url <- "https://www.statistik.at"
  current_year <- as.integer(format(Sys.Date(), "%Y"))

  if (is.null(year)) year <- current_year
  year <- as.integer(year)

  if (type == "marken" && year != current_year) {
    cli::cli_abort(c(
      "Historical brand data is not available in ODS format.",
      "i" = "Use {.fn statistik_get_pkw_neuzulassungen} for PKW brand data since January 2000."
    ))
  }

  # ---- 1. Discover all ODS file paths from static page HTML ----
  if (verbose) cli::cli_alert_info("Fetching Statistik Austria page to discover ODS files...")
  raw_lines <- tryCatch(
    readLines(page_url, warn = FALSE, encoding = "UTF-8"),
    error = function(e) cli::cli_abort("Could not read page: {conditionMessage(e)}")
  )
  all_paths <- unique(unlist(regmatches(
    raw_lines,
    gregexpr('/fileadmin/pages/77/[^"]+\\.ods', raw_lines)
  )))
  if (length(all_paths) == 0) {
    cli::cli_abort("No ODS files found on the page. The page structure may have changed.")
  }

  # ---- 2. Select the right file ----
  # Current year uses DE-prefixed files with monthly sheets.
  # Historical years use annual summary files.
  if (type == "marken") {
    # DE4: Neuzulassungen nach Marke × Fahrzeugart (monthly sheets)
    cands <- grep("DE4_", all_paths, value = TRUE)
    cands <- cands[!grepl("CO2", cands)]
    if (length(cands) == 0) {
      cli::cli_abort("Could not find the DE4 (brand) ODS file on the page.")
    }
    target_path <- cands[1]
    file_type   <- "marken_monthly"
  } else {
    if (year == current_year) {
      # DE3: Kraftstoff × Bundesland × Fahrzeugart (monthly sheets, URL changes each month)
      cands <- grep("DE3_", all_paths, value = TRUE)
      if (length(cands) == 0) {
        cli::cli_abort("Could not find the DE3 (Kraftstoff) ODS file on the page.")
      }
      target_path <- cands[1]
      file_type   <- "kraftstoff_monthly"
    } else {
      # Historical annual Kraftstoff+Bundesland file
      cands <- grep(as.character(year), all_paths, value = TRUE)
      cands <- grep("Kraftstoff|Energiequelle", cands, value = TRUE)
      if (length(cands) == 0) {
        avail <- basename(grep(as.character(year), all_paths, value = TRUE))
        cli::cli_abort(c(
          "No annual Kraftstoff file found for {year} on the page.",
          "i" = "Files for {year} on page: {paste(avail, collapse = ', ')}"
        ))
      }
      target_path <- cands[1]
      file_type   <- "kraftstoff_annual"
    }
  }

  file_url <- paste0(base_url, target_path)
  if (verbose) cli::cli_alert_info("Using: {.url {file_url}}")

  # ---- 3. Download ----
  tmp_ods <- tempfile(fileext = ".ods")
  resp <- tryCatch(
    httr::GET(file_url, httr::write_disk(tmp_ods, overwrite = TRUE)),
    error = function(e) cli::cli_abort("Download failed: {conditionMessage(e)}")
  )
  if (httr::status_code(resp) != 200) {
    cli::cli_abort("HTTP {httr::status_code(resp)} when downloading {file_url}")
  }
  if (verbose) cli::cli_alert_success("Downloaded ({round(file.size(tmp_ods)/1024)} KB)")

  # ---- 4. Determine sheets to parse ----
  sheets_available <- readODS::list_ods_sheets(tmp_ods)

  if (file_type == "kraftstoff_annual") {
    # Annual file has a single sheet named after the year
    sheets_to_use <- sheets_available
  } else {
    if (!is.null(months)) {
      missing_m <- setdiff(months, sheets_available)
      if (length(missing_m)) {
        cli::cli_alert_warning(
          "Sheet(s) not found and skipped: {paste(missing_m, collapse = ', ')}"
        )
      }
      sheets_to_use <- intersect(months, sheets_available)
    } else {
      sheets_to_use <- sheets_available
    }
  }

  if (length(sheets_to_use) == 0) {
    cli::cli_abort(
      "No matching sheets. Available: {paste(sheets_available, collapse = ', ')}"
    )
  }
  if (verbose) {
    cli::cli_alert_info(
      "Parsing {length(sheets_to_use)} sheet(s): {paste(sheets_to_use, collapse = ', ')}"
    )
  }

  # ---- 5. Helpers ----
  # Clean ODS multi-line text: "Personen-\nkraftwagen\nKlasse M1" -> "Personenkraftwagen Klasse M1"
  clean_label <- function(x) {
    x <- gsub("-\n", "", x, fixed = TRUE)
    x <- gsub("\n",  " ", x, fixed = TRUE)
    trimws(x)
  }

  conv <- function(x) {
    x <- trimws(as.character(x))
    dplyr::case_when(
      x == "-"                   ~ 0L,
      x == "/"                   ~ if (suppress_as_na) NA_integer_ else 0L,
      grepl("^[0-9 .]+$", x)    ~ as.integer(gsub("[^0-9]", "", x)),
      TRUE                       ~ NA_integer_
    )
  }

  # ---- 6. Sheet parsers ----
  parse_kraftstoff_sheet <- function(sheet_name) {
    raw <- suppressMessages(
      readODS::read_ods(tmp_ods, sheet = sheet_name, col_names = FALSE)
    )

    # Row 2: "Bundesland / Kraftfahrzeug" | "Benzin" | "Diesel" | "Elektro" | ...
    col_headers <- clean_label(as.character(unlist(raw[2, ])))
    col_headers[1] <- "label"
    fuel_cols <- col_headers[-1]   # column names for the fuel types

    data_rows <- raw[3:nrow(raw), ]
    keep <- vapply(data_rows[[1]], function(v) {
      v <- trimws(as.character(v))
      nzchar(v) && !grepl("^Q:|^Quelle|^NA$", v) && !is.na(v) && v != "NA"
    }, logical(1))
    data_rows <- data_rows[keep, ]

    # Align column count to headers
    if (ncol(data_rows) < length(col_headers)) {
      for (i in seq_len(length(col_headers) - ncol(data_rows))) {
        data_rows[[paste0(".pad", i)]] <- NA_character_
      }
    } else if (ncol(data_rows) > length(col_headers)) {
      data_rows <- data_rows[, seq_len(length(col_headers))]
    }
    colnames(data_rows) <- col_headers
    data_rows$label <- clean_label(data_rows$label)

    # Detect Bundesland hierarchy:
    # Rows whose label matches a known Bundesland are section headers
    # (representing totals for that state). All following rows until the next
    # Bundesland header belong to that state.
    current_bl    <- NA_character_
    bundesland_v  <- character(nrow(data_rows))
    is_bl_header  <- logical(nrow(data_rows))

    for (i in seq_len(nrow(data_rows))) {
      lbl <- data_rows$label[i]
      if (lbl %in% .BUNDESLAENDER_AT) {
        current_bl       <- lbl
        is_bl_header[i]  <- TRUE
      }
      bundesland_v[i] <- current_bl
    }

    data_rows$bundesland   <- bundesland_v
    # Bundesland header rows are "Insgesamt" totals for that state
    data_rows$fahrzeugtyp  <- ifelse(is_bl_header, "Insgesamt", data_rows$label)

    # Build the subset to pivot: bundesland + fahrzeugtyp + fuel columns
    pivot_df <- data_rows[, c("bundesland", "fahrzeugtyp", fuel_cols)]

    result <- tidyr::pivot_longer(
      pivot_df,
      cols      = seq_len(length(fuel_cols)) + 2L,  # positions after bundesland+fahrzeugtyp
      names_to  = "kraftstoffart",
      values_to = "anzahl_raw"
    )
    result$monat  <- sheet_name
    result$anzahl <- conv(result$anzahl_raw)
    result$anzahl_raw <- NULL
    result[c("monat", "bundesland", "fahrzeugtyp", "kraftstoffart", "anzahl")]
  }

  parse_marken_sheet <- function(sheet_name) {
    raw <- suppressMessages(
      readODS::read_ods(tmp_ods, sheet = sheet_name, col_names = FALSE)
    )

    col_headers <- clean_label(as.character(unlist(raw[2, ])))
    col_headers[1] <- "marke"

    data_rows <- raw[3:nrow(raw), ]
    keep <- vapply(data_rows[[1]], function(v) {
      v <- trimws(as.character(v))
      nzchar(v) && !grepl("^Q:|^Quelle|^NA$", v) && !is.na(v) && v != "NA"
    }, logical(1))
    data_rows <- data_rows[keep, ]
    colnames(data_rows) <- col_headers
    data_rows$marke <- clean_label(data_rows$marke)

    result <- tidyr::pivot_longer(
      data_rows,
      cols      = -marke,
      names_to  = "fahrzeugtyp",
      values_to = "anzahl_raw"
    )
    result$monat  <- sheet_name
    result$anzahl <- conv(result$anzahl_raw)
    result$anzahl_raw <- NULL
    result[c("monat", "marke", "fahrzeugtyp", "anzahl")]
  }

  # ---- 7. Parse all sheets and combine ----
  parse_fn <- if (type == "kraftstoff") parse_kraftstoff_sheet else parse_marken_sheet
  out <- dplyr::bind_rows(lapply(sheets_to_use, parse_fn))
  out$monat <- factor(out$monat, levels = sheets_to_use)

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(out)} rows | {length(sheets_to_use)} sheet(s)."
    )
  }
  tibble::as_tibble(out)
}
