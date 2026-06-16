#' Kfz-Neuzulassungen Zeitreihe nach Bundesland und Kraftstoffart (2006 – heute)
#'
#' Liefert monatliche Neuzulassungszahlen aus Statistik Austria. Kombiniert
#' gebündelte Historik (2006–2025) mit den jeweils aktuellen Daten des laufenden
#' Jahres, die dynamisch von der Statistik-Austria-Website geladen werden.
#'
#' @param fahrzeugtyp `"pkw"` (Standard) oder `NULL`.
#'   * `"pkw"` — nur Personenkraftwagen Klasse M1; Zeitreihe 2006 bis heute.
#'   * `NULL`  — alle Kfz-Typen; nur laufendes Jahr verfügbar, da die
#'     Historik ausschließlich PKW-Daten enthält.
#' @param kraftstoffart Character-Vektor der gewünschten Kraftstoffarten, z.B.
#'   `c("Elektro", "Diesel")`. `NULL` (Standard) liefert alle Kraftstoffarten.
#' @param bundesland Character-Vektor der gewünschten Bundesländer, z.B.
#'   `c("Wien", "Tirol")`. `"Österreich"` ist die nationale Summe. `NULL`
#'   (Standard) liefert alle Bundesländer.
#' @param date_from `"YYYY-MM"` oder `Date`. Nur Zeilen ab diesem Monat.
#'   Standard: `NULL` (alle verfügbaren Daten).
#' @param date_to `"YYYY-MM"` oder `Date`. Nur Zeilen bis zu diesem Monat.
#'   Standard: `NULL`.
#' @param include_current_year Logical. `TRUE` (Standard) lädt das aktuelle
#'   Jahr von Statistik Austria nach. `FALSE` gibt nur die gebündelte Historik
#'   zurück.
#' @param verbose Logical. Fortschrittsmeldungen ausgeben.
#' @param page_url URL der Statistik-Austria-Seite zur ODS-Erkennung.
#'
#' @return Ein `tibble` mit den Spalten:
#' \describe{
#'   \item{`bundesland`}{Bundesland oder `"Österreich"` (nationale Summe).}
#'   \item{`kraftstoffart`}{Kraftstoff- bzw. Antriebsart.}
#'   \item{`year`}{Jahr (Integer).}
#'   \item{`month`}{Monat (Integer, 1–12).}
#'   \item{`date`}{`Date`: erster Tag des Monats.}
#'   \item{`anzahl`}{Anzahl Neuzulassungen (Integer).}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # PKW-Zeitreihe 2006 bis heute (Standard)
#' statistik_neuzulassungen_zeitreihe()
#'
#' # Nur Elektro-PKW, Wien + national
#' statistik_neuzulassungen_zeitreihe(
#'   kraftstoffart = "Elektro",
#'   bundesland    = c("Wien", "Österreich")
#' )
#'
#' # Alle Kfz-Typen — nur aktuelles Jahr verfügbar
#' statistik_neuzulassungen_zeitreihe(fahrzeugtyp = NULL)
#'
#' # Seit 2020
#' statistik_neuzulassungen_zeitreihe(date_from = "2020-01")
#' }
statistik_neuzulassungen_zeitreihe <- function(
  fahrzeugtyp          = "pkw",
  kraftstoffart        = NULL,
  bundesland           = NULL,
  date_from            = NULL,
  date_to              = NULL,
  include_current_year = TRUE,
  verbose              = TRUE,
  page_url             = "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen"
) {
  pkw_only <- !is.null(fahrzeugtyp) && tolower(fahrzeugtyp) == "pkw"

  MONTH_NUM <- c(
    "Jänner" = 1L, "Februar" = 2L, "März" = 3L, "April" = 4L,
    "Mai" = 5L, "Juni" = 6L, "Juli" = 7L, "August" = 8L,
    "September" = 9L, "Oktober" = 10L, "November" = 11L, "Dezember" = 12L
  )
  VALID_MONTHS <- names(MONTH_NUM)

  # ---- 1. Gebündelte Historik (nur PKW) ----
  if (pkw_only) {
    if (verbose) cli::cli_alert_info("Loading bundled historical data (2006–2025, PKW only)...")
    hist <- at_pkw_kraftstoff_hist
    if (verbose) cli::cli_alert_success("{nrow(hist)} historical rows ({min(hist$date)} \u2013 {max(hist$date)})")
  } else {
    cli::cli_alert_warning(
      "Historische Daten (2006\u20132025) sind nur f\u00fcr PKW verf\u00fcgbar. ",
      "Es werden nur Daten des laufenden Jahres zur\u00fcckgegeben."
    )
    hist <- NULL
  }

  # ---- 2. Aktuelles Jahr von Statistik Austria ----
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
      de3_path <- grep("DE3_", all_paths, value = TRUE)

      if (length(de3_path) == 0) {
        cli::cli_alert_warning("Could not find DE3 ODS file on page. Skipping current-year data.")
      } else {
        file_url <- paste0("https://www.statistik.at", de3_path[1])
        if (verbose) cli::cli_alert_info("Using: {.url {file_url}}")

        tmp_ods <- tempfile(fileext = ".ods")
        resp <- tryCatch(
          httr::GET(file_url, httr::write_disk(tmp_ods, overwrite = TRUE)),
          error = function(e) { cli::cli_alert_warning("Download failed: {conditionMessage(e)}"); NULL }
        )

        if (!is.null(resp) && httr::status_code(resp) == 200) {
          if (verbose) cli::cli_alert_success("Downloaded ({round(file.size(tmp_ods)/1024)} KB)")

          month_sheets <- readODS::list_ods_sheets(tmp_ods)
          month_sheets <- month_sheets[month_sheets %in% VALID_MONTHS]

          parse_de3_sheet <- function(sheet_name) {
            raw <- suppressMessages(
              readODS::read_ods(tmp_ods, sheet = sheet_name, col_names = FALSE)
            )
            fuel_types <- trimws(gsub("-\n|\n", " ", as.character(unlist(raw[2, -1]))))
            data_rows  <- raw[3:nrow(raw), ]
            labels     <- trimws(as.character(data_rows[[1]]))

            bl_labels_set <- c(
              "\u00d6sterreich", "Burgenland", "K\u00e4rnten", "Nieder\u00f6sterreich",
              "Ober\u00f6sterreich", "Salzburg", "Steiermark", "Tirol",
              "Vorarlberg", "Wien"
            )

            current_bl  <- NA_character_
            result_rows <- list()

            for (i in seq_len(nrow(data_rows))) {
              lbl <- labels[i]
              if (lbl %in% bl_labels_set) {
                current_bl <- lbl
                if (!pkw_only) {
                  # alle Kfz: Insgesamt-Zeile des Bundeslandes verwenden
                  vals <- as.character(unlist(data_rows[i, -1]))
                  n    <- min(length(vals), length(fuel_types))
                  result_rows[[length(result_rows) + 1]] <- data.frame(
                    bundesland    = current_bl,
                    kraftstoffart = fuel_types[seq_len(n)],
                    anzahl_raw    = vals[seq_len(n)],
                    stringsAsFactors = FALSE
                  )
                }
                next
              }
              if (pkw_only && !is.na(current_bl) &&
                  grepl("Personenkraft", lbl, ignore.case = TRUE)) {
                vals <- as.character(unlist(data_rows[i, -1]))
                n    <- min(length(vals), length(fuel_types))
                result_rows[[length(result_rows) + 1]] <- data.frame(
                  bundesland    = current_bl,
                  kraftstoffart = fuel_types[seq_len(n)],
                  anzahl_raw    = vals[seq_len(n)],
                  stringsAsFactors = FALSE
                )
              }
            }

            if (length(result_rows) == 0) return(NULL)
            res       <- do.call(rbind, result_rows)
            res$monat <- sheet_name
            res
          }

          sheets_parsed <- Filter(Negate(is.null), lapply(month_sheets, parse_de3_sheet))

          if (length(sheets_parsed) > 0) {
            cur_raw      <- do.call(rbind, sheets_parsed)
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

            if (verbose)
              cli::cli_alert_success(
                "{nrow(current_data)} current-year rows ({length(month_sheets)} month(s))"
              )
          }
        }
      }
    }
  }

  # ---- 3. Kombinieren ----
  out <- if (!is.null(hist) && !is.null(current_data)) {
    hist_trimmed <- dplyr::filter(hist, year < as.integer(format(Sys.Date(), "%Y")))
    dplyr::bind_rows(hist_trimmed, current_data)
  } else if (!is.null(hist)) {
    hist
  } else if (!is.null(current_data)) {
    current_data
  } else {
    stop("Keine Daten verfügbar.")
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
  if (!is.null(bundesland))    out <- dplyr::filter(out, bundesland %in% bundesland)
  if (!is.null(kraftstoffart)) out <- dplyr::filter(out, kraftstoffart %in% kraftstoffart)

  if (verbose) {
    cli::cli_alert_success(
      "Done. {nrow(out)} rows | {length(unique(out$bundesland))} state(s) | {length(unique(out$kraftstoffart))} fuel type(s) | {min(out$date)} \u2013 {max(out$date)}"
    )
  }

  tibble::as_tibble(out)
}

#' @rdname statistik_neuzulassungen_zeitreihe
#' @export
statistik_pkw_neuzulassungen_zeitreihe <- function(...) statistik_neuzulassungen_zeitreihe(fahrzeugtyp = "pkw", ...)

#' @rdname statistik_neuzulassungen_zeitreihe
#' @export
statistik_pkw_kraftstoff_zeitreihe <- function(...) statistik_neuzulassungen_zeitreihe(fahrzeugtyp = "pkw", ...)
