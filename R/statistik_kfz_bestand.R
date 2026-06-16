# Known Bundesland names in canonical order (headers in ODS are truncated)
.BESTAND_BUNDESLAENDER <- c(
  "Österreich", "Burgenland", "Kärnten", "Niederösterreich",
  "Oberösterreich", "Salzburg", "Steiermark", "Tirol", "Vorarlberg", "Wien"
)

# Canonical vehicle-type column names for annual tab_7 (positions 2–10 after row label)
.TAB7_FAHRZEUGARTEN <- c(
  "Kfz insgesamt",
  "Personenkraftwagen",
  "Krafträder",
  "Motorfahrräder",
  "Lkw Klasse N1",
  "Lkw Klasse N2+N3",
  "Sattelzugfahrzeuge",
  "Zugmaschinen",
  "Sonstige Kfz"
)

#' Kfz-Bestand nach Fahrzeugart oder Kraftstoffart (Zeitreihe)
#'
#' Downloads all available Statistik Austria Kfz-Bestand ODS files and returns
#' a combined tidy tibble. Two data types are available via the `type` argument:
#'
#' \describe{
#'   \item{`"fahrzeugart"` (default)}{Vehicle counts by Fahrzeugart and Bundesland.
#'     Annual files (tab_7) cover 2019–2025 with 9 broad categories. The vorläufig
#'     file provides more granular categories plus Anhänger by Bundesland.}
#'   \item{`"kraftstoff"`}{Kfz counts by Kraftstoffart and Bundesland.
#'     Annual files are available for 2024–2025 (all vehicle types). The vorläufig
#'     file adds a PKW-only kraftstoff breakdown for the latest quarter.}
#' }
#'
#' **Data sources:**
#' \describe{
#'   \item{`type = "fahrzeugart"`, annual}{`tab_7` sheet — 2019–2025.
#'     Broad Kfz categories by Bundesland. Anhänger are Austria-total only.}
#'   \item{`type = "fahrzeugart"`, vorläufig}{`Fahrzeuge` sheet — latest quarter.
#'     Granular categories + Anhänger by Bundesland.}
#'   \item{`type = "kraftstoff"`, annual}{`Kfz-BestandKraftfahrzeugBundeslandKraftstoffartEnergiequelle{year}.ods`
#'     — currently 2024–2025. All vehicle types × Kraftstoffart × Bundesland.}
#'   \item{`type = "kraftstoff"`, vorläufig}{`Pkw_nach_Kraftstoff` sheet — latest
#'     quarter. PKW only × Kraftstoffart × Bundesland.}
#' }
#'
#' Files are discovered dynamically from the Statistik Austria page.
#'
#' @param type Character. One of `"fahrzeugart"` (default) or `"kraftstoff"`.
#' @param include_vorlaeufig Logical. If `TRUE` (default), appends the most
#'   recent preliminary (vorläufig) figure (e.g. 31. März 2026).
#' @param verbose Logical. Print progress messages. Default `TRUE`.
#' @param page_url The Statistik Austria page to discover ODS links from.
#'
#' @return A `tibble`. Columns for `type = "fahrzeugart"`:
#' \describe{
#'   \item{`stichtag`}{`Date`.}
#'   \item{`vorlaeufig`}{Logical.}
#'   \item{`section`}{`"Kraftfahrzeuge"` or `"Anhänger"`.}
#'   \item{`bundesland`}{State name or `"Österreich"`.}
#'   \item{`fahrzeugart`}{Vehicle type.}
#'   \item{`anzahl`}{Integer count.}
#' }
#' Columns for `type = "kraftstoff"`:
#' \describe{
#'   \item{`stichtag`}{`Date`.}
#'   \item{`vorlaeufig`}{Logical.}
#'   \item{`bundesland`}{State name or `"Österreich"`.}
#'   \item{`fahrzeugart`}{Vehicle type. For the vorläufig file always
#'     `"Personenkraftwagen Klasse M1"` (PKW-only sheet).}
#'   \item{`kraftstoffart`}{Fuel/energy source, e.g. `"Elektro"`, `"Diesel"`.}
#'   \item{`anzahl`}{Integer count.}
#' }
#'
#' @source \url{https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-bestand}
#'
#' @importFrom readODS read_ods list_ods_sheets
#' @importFrom tidyr pivot_longer
#' @importFrom dplyr bind_rows arrange
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_abort
#' @importFrom httr GET write_disk status_code
#'
#' @export
#' @examples
#' \dontrun{
#' # ---- Fahrzeugart (default) ----
#' statistik_kfz_bestand()
#' statistik_kfz_bestand(include_vorlaeufig = FALSE)
#'
#' # PKW over time by Bundesland
#' statistik_kfz_bestand() |>
#'   dplyr::filter(section == "Kraftfahrzeuge",
#'                 fahrzeugart == "Personenkraftwagen",
#'                 bundesland != "Österreich")
#'
#' # ---- Kraftstoff ----
#' statistik_kfz_bestand(type = "kraftstoff")
#'
#' # Elektro-PKW by Bundesland
#' statistik_kfz_bestand(type = "kraftstoff") |>
#'   dplyr::filter(fahrzeugart == "Personenkraftwagen Klasse M1",
#'                 kraftstoffart == "Elektro")
#' }
statistik_kfz_bestand <- function(
  type               = c("fahrzeugart", "kraftstoff"),
  include_vorlaeufig = TRUE,
  verbose            = TRUE,
  page_url           = "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-bestand"
) {
  type     <- match.arg(type)
  base_url <- "https://www.statistik.at"

  # ---- 1. Discover ODS links ----
  if (verbose) cli::cli_alert_info("Fetching Statistik Austria Bestand page...")
  raw_lines <- tryCatch(
    readLines(page_url, warn = FALSE, encoding = "UTF-8"),
    error = function(e) cli::cli_abort("Could not read page: {conditionMessage(e)}")
  )
  all_paths <- unique(unlist(regmatches(
    raw_lines,
    gregexpr('"/fileadmin/pages/75/[^"]+\\.ods"', raw_lines)
  )))
  all_paths <- gsub('"', "", all_paths)
  if (length(all_paths) == 0) {
    cli::cli_abort("No ODS files found on the Bestand page. The page structure may have changed.")
  }

  # Vorläufig file (shared across both types)
  vorl_path <- NULL
  if (include_vorlaeufig) {
    cands <- all_paths[grepl("vorl", all_paths, ignore.case = TRUE)]
    if (length(cands) > 0) vorl_path <- cands[1] else
      cli::cli_alert_warning("No vorläufig ODS file found on the page — skipping.")
  }

  # ---- shared helper: download ----
  .download <- function(path, label) {
    url <- paste0(base_url, path)
    if (verbose) cli::cli_alert_info("Downloading {label}: {basename(path)}")
    tmp <- tempfile(fileext = ".ods")
    resp <- tryCatch(
      httr::GET(url, httr::write_disk(tmp, overwrite = TRUE)),
      error = function(e) { cli::cli_alert_warning("Failed: {conditionMessage(e)}"); NULL }
    )
    if (is.null(resp) || httr::status_code(resp) != 200) {
      cli::cli_alert_warning("HTTP error for {basename(path)} — skipping.")
      return(NULL)
    }
    if (verbose) cli::cli_alert_success("  {round(file.size(tmp)/1024)} KB")
    tmp
  }

  .clean_int <- function(x) {
    x <- trimws(as.character(x))
    v <- suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
    v[x == "-"] <- NA_integer_
    v
  }

  # ===========================================================================
  # TYPE = "fahrzeugart"
  # ===========================================================================
  if (type == "fahrzeugart") {

    annual_paths <- all_paths[grepl("kfz-bestand_\\d{4}|BestandFahrzeuge\\d{4}", all_paths,
                                     ignore.case = TRUE)]
    annual_paths <- annual_paths[!grepl("Bundesland|Kraftstoff|Energiequelle", annual_paths,
                                         ignore.case = TRUE)]
    if (length(annual_paths) == 0) {
      cli::cli_abort("No annual Kfz-Bestand ODS files found on the page.")
    }
    annual_years <- as.integer(regmatches(annual_paths, regexpr("\\d{4}", annual_paths)))
    annual_paths <- annual_paths[order(annual_years)]
    annual_years <- sort(annual_years)

    .parse_annual <- function(tmp_ods, fallback_year) {
      sheets <- readODS::list_ods_sheets(tmp_ods)
      sheet  <- sheets[grepl("^tab_7$|^7$", sheets)][1]
      if (is.na(sheet)) {
        cli::cli_alert_warning("tab_7 not found — skipping this year.")
        return(NULL)
      }
      raw <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))
      date_match <- regmatches(as.character(raw[1,1]),
                               regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", as.character(raw[1,1])))
      stichtag <- if (length(date_match) == 1) as.Date(date_match, "%d.%m.%Y") else
        as.Date(paste0(fallback_year, "-12-31"))
      col1   <- as.character(raw[[1]])
      bl_idx <- grep("^Österreich$|insgesamt$", col1)
      if (length(bl_idx) == 0) return(NULL)
      data_rows <- raw[bl_idx, ]
      bl_labels <- trimws(gsub("\\s*insgesamt$", "", as.character(data_rows[[1]])))
      n_vt     <- min(ncol(data_rows) - 1L, length(.TAB7_FAHRZEUGARTEN))
      vt_names <- .TAB7_FAHRZEUGARTEN[seq_len(n_vt)]
      result <- lapply(seq_len(nrow(data_rows)), function(i) {
        vals <- .clean_int(unlist(data_rows[i, 2:(n_vt + 1)]))
        data.frame(stichtag = stichtag, vorlaeufig = FALSE, section = "Kraftfahrzeuge",
                   bundesland = bl_labels[i], fahrzeugart = vt_names, anzahl = vals,
                   stringsAsFactors = FALSE)
      })
      anhaenger <- .parse_annual_anhaenger(tmp_ods, stichtag)
      do.call(rbind, c(result, list(anhaenger)))
    }

    .parse_annual_anhaenger <- function(tmp_ods, stichtag) {
      sheets <- readODS::list_ods_sheets(tmp_ods)
      sheet  <- sheets[grepl("^tab_1$|^1$", sheets)][1]
      if (is.na(sheet)) return(NULL)
      raw  <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))
      col1 <- as.character(raw[[1]])
      b_start <- which(grepl("Tabelle 1b|Anh.nger-Bestand", col1, ignore.case = TRUE))[1]
      if (is.na(b_start)) return(NULL)
      data_start <- b_start + 2L
      q_row    <- which(grepl("^Q:", col1) & seq_along(col1) > b_start)[1]
      data_end <- if (!is.na(q_row)) q_row - 1L else nrow(raw)
      if (data_start > data_end) return(NULL)
      data_rows <- raw[data_start:data_end, ]
      data_rows <- data_rows[!is.na(data_rows[[1]]) & trimws(data_rows[[1]]) != "", ]
      if (nrow(data_rows) == 0) return(NULL)
      data.frame(stichtag = stichtag, vorlaeufig = FALSE, section = "Anhänger",
                 bundesland = "Österreich",
                 fahrzeugart = trimws(as.character(data_rows[[1]])),
                 anzahl = .clean_int(data_rows[[2]]), stringsAsFactors = FALSE)
    }

    .parse_vorlaeufig_fahrzeugart <- function(tmp_ods) {
      sheets <- readODS::list_ods_sheets(tmp_ods)
      sheet  <- sheets[grepl("^Fahrzeuge$", sheets, ignore.case = TRUE)][1]
      if (is.na(sheet)) {
        cli::cli_alert_warning("'Fahrzeuge' sheet not found in vorläufig file.")
        return(NULL)
      }
      raw  <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))
      col1 <- as.character(raw[[1]])
      date_match <- regmatches(col1[1], regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", col1[1]))
      stichtag   <- if (length(date_match) == 1) as.Date(date_match, "%d.%m.%Y") else NA
      q_rows     <- which(grepl("^Q:", col1))
      title_rows <- which(grepl("^Vorläufig", col1))

      .parse_section <- function(header_row_idx, data_start, data_end, section_name) {
        bl_raw   <- as.character(unlist(raw[header_row_idx, -1]))
        bl_names <- .BESTAND_BUNDESLAENDER[seq_len(length(bl_raw))]
        data_part <- raw[data_start:data_end, ]
        data_part <- data_part[!is.na(data_part[[1]]) & trimws(data_part[[1]]) != "", ]
        result <- lapply(seq_len(nrow(data_part)), function(i) {
          fz   <- trimws(as.character(data_part[i, 1]))
          vals <- .clean_int(unlist(data_part[i, 2:(length(bl_names) + 1)]))
          data.frame(stichtag = stichtag, vorlaeufig = TRUE, section = section_name,
                     bundesland = bl_names, fahrzeugart = fz, anzahl = vals,
                     stringsAsFactors = FALSE)
        })
        do.call(rbind, result)
      }

      parts <- list()
      if (length(title_rows) >= 1 && length(q_rows) >= 1) {
        h1 <- title_rows[1] + 1L
        if (h1 + 1L <= q_rows[1] - 1L)
          parts[[1]] <- .parse_section(h1, h1 + 1L, q_rows[1] - 1L, "Kraftfahrzeuge")
      }
      if (length(title_rows) >= 2 && length(q_rows) >= 2) {
        h2 <- title_rows[2] + 1L
        if (h2 + 1L <= q_rows[2] - 1L)
          parts[[2]] <- .parse_section(h2, h2 + 1L, q_rows[2] - 1L, "Anhänger")
      }
      if (length(parts) == 0) return(NULL)
      do.call(rbind, parts)
    }

    all_dfs <- list()
    for (i in seq_along(annual_paths)) {
      tmp <- .download(annual_paths[i], as.character(annual_years[i]))
      if (is.null(tmp)) next
      df <- .parse_annual(tmp, annual_years[i])
      if (!is.null(df)) all_dfs[[length(all_dfs) + 1]] <- df
    }
    if (!is.null(vorl_path)) {
      tmp <- .download(vorl_path, "vorläufig")
      if (!is.null(tmp)) {
        df <- .parse_vorlaeufig_fahrzeugart(tmp)
        if (!is.null(df)) all_dfs[[length(all_dfs) + 1]] <- df
      }
    }

    if (length(all_dfs) == 0) cli::cli_abort("No data could be retrieved.")
    out <- dplyr::bind_rows(all_dfs)
    out <- out[!grepl("insgesamt", out$fahrzeugart, ignore.case = TRUE), ]
    out <- out[, c("stichtag", "vorlaeufig", "section", "bundesland", "fahrzeugart", "anzahl")]
    out <- dplyr::arrange(out, stichtag, section, bundesland, fahrzeugart)
    out <- tibble::as_tibble(out)
    if (verbose) {
      stichtage <- sort(unique(out$stichtag))
      cli::cli_alert_success(
        "Done. {nrow(out)} rows | {length(stichtage)} Stichtage ({min(stichtage)} \u2013 {max(stichtage)})"
      )
    }
    return(out)
  }

  # ===========================================================================
  # TYPE = "kraftstoff"
  #
  # Two source types, used in combination:
  #
  # A) Standalone Kraftstoffart files (currently 2024+):
  #    Kfz-BestandKraftfahrzeugBundeslandKraftstoffartEnergiequelle{year}.ods
  #    → ALL vehicle types × Kraftstoffart × Bundesland.
  #    Bundesland rows are section headers; vehicle-type sub-rows follow.
  #
  # B) tab_3 inside the main annual bestand files (2019–present):
  #    "Tabelle 3: Pkw-Bestand ... nach Kraftstoffart ... Absolut"
  #    → PKW only (fahrzeugart = "Personenkraftwagen") × Kraftstoffart × Bundesland.
  #    Used for years where no standalone file (A) exists to avoid duplicates.
  #
  # C) Vorläufig Pkw_nach_Kraftstoff sheet — PKW only × Kraftstoffart × Bundesland.
  # ===========================================================================

  # ---- A: standalone Kraftstoffart files ----
  kraft_paths <- all_paths[grepl("KraftstoffartEnergiequelle|KraftfahrzeugBundeslandKraftstoff",
                                  all_paths, ignore.case = TRUE)]
  kraft_years <- if (length(kraft_paths) > 0)
    sort(as.integer(regmatches(kraft_paths, regexpr("\\d{4}", kraft_paths))))
  else integer(0)
  kraft_paths <- if (length(kraft_paths) > 0)
    kraft_paths[order(as.integer(regmatches(kraft_paths, regexpr("\\d{4}", kraft_paths))))]
  else character(0)

  # ---- Annual main files (for tab_3, source B) ----
  annual_paths <- all_paths[grepl("kfz-bestand_\\d{4}|BestandFahrzeuge\\d{4}", all_paths,
                                   ignore.case = TRUE)]
  annual_paths <- annual_paths[!grepl("Bundesland|Kraftstoff|Energiequelle", annual_paths,
                                       ignore.case = TRUE)]
  annual_years <- if (length(annual_paths) > 0)
    sort(as.integer(regmatches(annual_paths, regexpr("\\d{4}", annual_paths))))
  else integer(0)
  annual_paths <- if (length(annual_paths) > 0)
    annual_paths[order(as.integer(regmatches(annual_paths, regexpr("\\d{4}", annual_paths))))]
  else character(0)

  # Parser A: standalone all-vehicle-type Kraftstoffart file
  .parse_kraftstoff_annual <- function(tmp_ods, fallback_year) {
    sheets <- readODS::list_ods_sheets(tmp_ods)
    sheet  <- sheets[grepl("^\\d{4}$", sheets)][1]
    if (is.na(sheet)) sheet <- sheets[1]
    raw <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))

    date_match <- regmatches(as.character(raw[1, 1]),
                             regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", as.character(raw[1, 1])))
    stichtag <- if (length(date_match) == 1) as.Date(date_match, "%d.%m.%Y") else
      as.Date(paste0(fallback_year, "-12-31"))

    # Kraftstoffart names from row 2 (all columns except the label column)
    kraft_names <- trimws(gsub("\n", " ", as.character(unlist(raw[2, -1]))))
    kraft_names <- kraft_names[!is.na(kraft_names) & nzchar(kraft_names)]

    data_rows  <- raw[3:nrow(raw), ]
    col1       <- trimws(as.character(data_rows[[1]]))
    current_bl <- NA_character_
    results    <- list()

    for (i in seq_len(nrow(data_rows))) {
      label <- col1[i]
      if (is.na(label) || !nzchar(label)) next
      if (grepl("^Q:", label)) break
      if (label %in% .BESTAND_BUNDESLAENDER) { current_bl <- label; next }
      if (is.na(current_bl)) next
      n    <- min(ncol(data_rows) - 1L, length(kraft_names))
      vals <- .clean_int(unlist(data_rows[i, 2:(n + 1)]))
      results[[length(results) + 1]] <- data.frame(
        stichtag = stichtag, vorlaeufig = FALSE, bundesland = current_bl,
        fahrzeugart = label, kraftstoffart = kraft_names[seq_len(n)], anzahl = vals,
        stringsAsFactors = FALSE
      )
    }
    if (length(results) == 0) return(NULL)
    do.call(rbind, results)
  }

  # Parser B: tab_3 in the main annual file — PKW only
  # Row1 = title (has date), row2 = BL headers, rows3–first Q: = absolute counts.
  # A second sub-table (% shares) follows after the first Q: row — we stop there.
  .parse_tab3_pkw <- function(tmp_ods, fallback_year) {
    sheets <- readODS::list_ods_sheets(tmp_ods)
    sheet  <- sheets[grepl("^tab_3$", sheets)][1]
    if (is.na(sheet)) return(NULL)

    raw  <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))
    col1 <- trimws(as.character(raw[[1]]))

    date_match <- regmatches(col1[1], regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", col1[1]))
    stichtag   <- if (length(date_match) == 1) as.Date(date_match, "%d.%m.%Y") else
      as.Date(paste0(fallback_year, "-12-31"))

    # Bundesland names from row 2
    n_bl     <- sum(!is.na(unlist(raw[2, -1])) &
                    nzchar(trimws(as.character(unlist(raw[2, -1])))))
    bl_names <- .BESTAND_BUNDESLAENDER[seq_len(n_bl)]

    # Data rows 3 through (first Q: row − 1) — only the absolute-counts section
    q_row    <- which(grepl("^Q:", col1))[1]
    data_end <- if (!is.na(q_row)) q_row - 1L else nrow(raw)
    data_rows <- raw[3:data_end, ]
    col1_data <- trimws(as.character(data_rows[[1]]))
    keep <- !grepl("insgesamt|^darunter", col1_data, ignore.case = TRUE) &
            !is.na(col1_data) & nzchar(col1_data)
    data_rows <- data_rows[keep, ]
    col1_data <- col1_data[keep]

    results <- lapply(seq_len(nrow(data_rows)), function(i) {
      vals <- .clean_int(unlist(data_rows[i, 2:(n_bl + 1)]))
      data.frame(
        stichtag = stichtag, vorlaeufig = FALSE, bundesland = bl_names,
        fahrzeugart = "Personenkraftwagen", kraftstoffart = col1_data[i], anzahl = vals,
        stringsAsFactors = FALSE
      )
    })
    if (length(results) == 0) return(NULL)
    do.call(rbind, results)
  }

  # Parser C: vorläufig Pkw_nach_Kraftstoff sheet — PKW only
  .parse_vorlaeufig_kraftstoff <- function(tmp_ods) {
    sheets <- readODS::list_ods_sheets(tmp_ods)
    sheet  <- sheets[grepl("Pkw_nach_Kraftstoff|Kraftstoff", sheets, ignore.case = TRUE)][1]
    if (is.na(sheet)) {
      cli::cli_alert_warning("'Pkw_nach_Kraftstoff' sheet not found in vorläufig file — skipping.")
      return(NULL)
    }
    raw  <- suppressMessages(readODS::read_ods(tmp_ods, sheet = sheet, col_names = FALSE))
    col1 <- trimws(as.character(raw[[1]]))

    date_match <- regmatches(col1[1], regexpr("\\d{2}\\.\\d{2}\\.\\d{4}", col1[1]))
    stichtag   <- if (length(date_match) == 1) as.Date(date_match, "%d.%m.%Y") else NA

    # Bundesland names from row 2; use canonical list
    n_bl     <- sum(!is.na(unlist(raw[2, -1])) &
                    nzchar(trimws(as.character(unlist(raw[2, -1])))))
    bl_names <- .BESTAND_BUNDESLAENDER[seq_len(n_bl)]

    # Rows 3+: kraftstoffart rows — skip "insgesamt", "darunter", and "Q:" rows
    data_rows  <- raw[3:nrow(raw), ]
    col1_data  <- trimws(as.character(data_rows[[1]]))
    keep <- !grepl("^Q:|insgesamt|^darunter", col1_data, ignore.case = TRUE) &
            !is.na(col1_data) & nzchar(col1_data)
    data_rows <- data_rows[keep, ]
    col1_data <- col1_data[keep]

    results <- lapply(seq_len(nrow(data_rows)), function(i) {
      vals <- .clean_int(unlist(data_rows[i, 2:(n_bl + 1)]))
      data.frame(
        stichtag = stichtag, vorlaeufig = TRUE, bundesland = bl_names,
        fahrzeugart = "Personenkraftwagen Klasse M1",
        kraftstoffart = col1_data[i], anzahl = vals,
        stringsAsFactors = FALSE
      )
    })
    if (length(results) == 0) return(NULL)
    do.call(rbind, results)
  }

  # ---- Download + parse ----
  all_dfs <- list()

  # A: standalone Kraftstoffart files (all-vehicle-type detail)
  for (i in seq_along(kraft_paths)) {
    tmp <- .download(kraft_paths[i], as.character(kraft_years[i]))
    if (is.null(tmp)) next
    df <- .parse_kraftstoff_annual(tmp, kraft_years[i])
    if (!is.null(df)) all_dfs[[length(all_dfs) + 1]] <- df
  }

  # B: tab_3 from main annual files — only for years not covered by A
  tab3_years <- setdiff(annual_years, kraft_years)
  if (length(tab3_years) > 0) {
    tab3_paths <- annual_paths[annual_years %in% tab3_years]
    for (i in seq_along(tab3_paths)) {
      tmp <- .download(tab3_paths[i], paste0(tab3_years[i], " (tab_3)"))
      if (is.null(tmp)) next
      df <- .parse_tab3_pkw(tmp, tab3_years[i])
      if (!is.null(df)) all_dfs[[length(all_dfs) + 1]] <- df
    }
  }

  # C: vorläufig
  if (!is.null(vorl_path)) {
    tmp <- .download(vorl_path, "vorläufig")
    if (!is.null(tmp)) {
      df <- .parse_vorlaeufig_kraftstoff(tmp)
      if (!is.null(df)) all_dfs[[length(all_dfs) + 1]] <- df
    }
  }

  if (length(all_dfs) == 0) cli::cli_abort("No kraftstoff data could be retrieved.")
  out <- dplyr::bind_rows(all_dfs)
  out <- out[, c("stichtag", "vorlaeufig", "bundesland", "fahrzeugart", "kraftstoffart", "anzahl")]
  out <- dplyr::arrange(out, stichtag, bundesland, fahrzeugart, kraftstoffart)
  out <- tibble::as_tibble(out)

  if (verbose) {
    stichtage <- sort(unique(out$stichtag))
    cli::cli_alert_success(
      "Done. {nrow(out)} rows | {length(stichtage)} Stichtage ({min(stichtage)} \u2013 {max(stichtage)})"
    )
  }
  out
}

