# ============================================================================
# KBA Fahrzeugzulassungen – FZ 28
# Monatliche Neuzulassungen von Kraftfahrzeugen mit alternativem Antrieb
# (u. a. Bundesländer, PKW-Monate, Marken, Segmente)
# ============================================================================

.KBA_FZ28_PAGE_URL <- paste0(
  "https://www.kba.de/DE/Statistik/Produktkatalog/produkte/",
  "Fahrzeuge/fz28/fz28_gentab.html?nn=835828"
)

.KBA_BUNDESLAENDER <- c(
  "Baden-W\u00fcrttemberg",
  "Bayern",
  "Berlin",
  "Brandenburg",
  "Bremen",
  "Hamburg",
  "Hessen",
  "Mecklenburg-Vorpommern",
  "Niedersachsen",
  "Nordrhein-Westfalen",
  "Rheinland-Pfalz",
  "Saarland",
  "Sachsen",
  "Sachsen-Anhalt",
  "Schleswig-Holstein",
  "Th\u00fcringen"
)

.KBA_FZ28_SHEETS <- c(
  kfz_fahrzeugarten = "FZ 28.1",
  pkw_monate        = "FZ 28.2",
  pkw_halter        = "FZ 28.3",
  pkw_marken        = "FZ 28.4",
  pkw_marken_jahr   = "FZ 28.5",
  pkw_segmente      = "FZ 28.8",
  pkw_bundeslaender = "FZ 28.9"
)

# ── interne Helfer (FZ 28) ───────────────────────────────────────────────────

.kba_fz28_berichtsmonat_from_file <- function(file) {
  fname <- basename(file)
  m <- regexpr("fz28_(\\d{4})_(\\d{2})", fname, perl = TRUE)
  if (m < 0L) return(as.Date(NA))
  parts <- regmatches(fname, regexec("fz28_(\\d{4})_(\\d{2})", fname, perl = TRUE))[[1L]]
  as.Date(sprintf("%s-%s-01", parts[2L], parts[3L]))
}

.kba_fz28_berichtsmonat_from_raw <- function(raw) {
  labels <- .kba_chr(raw[[1L]])
  hits <- vapply(
    labels,
    function(l) !is.na(.kba_fz28_berichtsmonat_from_label(l)),
    logical(1L)
  )
  if (!any(hits)) {
    return(as.Date(NA))
  }
  .kba_fz28_berichtsmonat_from_label(labels[which(hits)[1L]])
}

.kba_fz28_berichtsmonat_from_label <- function(label) {
  label <- trimws(as.character(label))
  parts <- strsplit(label, "\\s+")[[1L]]
  if (length(parts) < 2L) return(as.Date(NA))
  month <- unname(.KBA_DE_MONTHS[parts[1L]])
  year  <- suppressWarnings(as.integer(parts[2L]))
  if (is.na(month) || is.na(year)) return(as.Date(NA))
  as.Date(sprintf("%04d-%02d-01", year, month))
}

.kba_fz28_entity_ebene <- function(entity, berichtsmonat) {
  dplyr::case_when(
    entity %in% .KBA_BUNDESLAENDER ~ "bundesland",
    grepl("^Jahr\\s", entity) ~ "jahr_gesamt",
    entity %in% names(.KBA_DE_MONTHS) ~ "monat",
    !is.na(.kba_fz28_berichtsmonat_from_label(entity)) ~ "berichtsmonat",
    TRUE ~ "sonstige"
  )
}

.kba_fz28_is_monats_label <- function(label) {
  parts <- strsplit(trimws(label), "\\s+")[[1L]]
  length(parts) == 2L &&
    !is.na(.KBA_DE_MONTHS[parts[1L]]) &&
    !is.na(suppressWarnings(as.integer(parts[2L])))
}

.kba_fz28_is_jahr_bisher_label <- function(label) {
  grepl("^Januar\\s+-\\s+", label) ||
    grepl("insgesamt$", label, ignore.case = TRUE)
}

.kba_fz28_zeitraum_vector <- function(labels) {
  zeitraum <- rep(NA_character_, length(labels))
  current <- NA_character_

  for (i in seq_along(labels)) {
    lab <- labels[i]
    if (is.na(lab) || lab == "") next

    if (.kba_fz28_is_monats_label(lab)) {
      current <- "monat"
    } else if (.kba_fz28_is_jahr_bisher_label(lab)) {
      current <- "jahr_bisher"
    }

    zeitraum[i] <- current
  }

  zeitraum
}

.kba_fz28_data_rows <- function(raw) {
  n <- nrow(raw)
  if (n < 12L) return(raw[0, ])

  labels <- .kba_chr(raw[[1L]])
  counts <- .kba_int(raw[[2L]])

  idx <- which(
    !is.na(labels) &
      labels != "" &
      !grepl("^zur", labels, ignore.case = TRUE) &
      !is.na(counts)
  )
  if (length(idx) == 0L) return(raw[0, ])

  raw[idx, , drop = FALSE]
}

.kba_parse_fz28_alt_antrieb <- function(
    raw,
    entity_name,
    berichtsmonat = NULL,
    keep_entities = NULL,
    zeitraum = c("alle", "monat", "jahr_bisher")
) {
  zeitraum <- match.arg(zeitraum)
  dr <- .kba_fz28_data_rows(raw)
  if (nrow(dr) == 0L) {
    return(tibble::tibble())
  }

  entity <- .kba_chr(dr[[1L]])
  zeitraum_vec <- .kba_fz28_zeitraum_vector(entity)

  if (zeitraum != "alle") {
    keep_z <- !is.na(zeitraum_vec) & zeitraum_vec == zeitraum
    dr <- dr[keep_z, , drop = FALSE]
    entity <- entity[keep_z]
    zeitraum_vec <- zeitraum_vec[keep_z]
  }

  if (!is.null(keep_entities)) {
    keep_e <- entity %in% keep_entities
    dr <- dr[keep_e, , drop = FALSE]
    entity <- entity[keep_e]
    zeitraum_vec <- zeitraum_vec[keep_e]
  }
  if (nrow(dr) == 0L) {
    return(tibble::tibble())
  }

  if (is.null(berichtsmonat)) {
    bm_label <- entity[entity %in% names(.KBA_DE_MONTHS) |
      !is.na(.kba_fz28_berichtsmonat_from_label(entity))]
    if (length(bm_label) > 0L) {
      berichtsmonat <- .kba_fz28_berichtsmonat_from_label(bm_label[1L])
    }
  }

  tibble::tibble(
    berichtsmonat       = berichtsmonat,
    zeitraum            = zeitraum_vec,
    entity              = entity,
    entity_ebene        = .kba_fz28_entity_ebene(entity, berichtsmonat),
    insgesamt_n         = .kba_int(dr[[2L]]),
    alternativ_n        = .kba_int(dr[[3L]]),
    alternativ_pct      = .kba_num(dr[[4L]]),
    elektro_gesamt_n    = .kba_int(dr[[5L]]),
    elektro_gesamt_pct  = .kba_num(dr[[6L]]),
    bev_n               = .kba_int(dr[[7L]]),
    brennstoffzelle_n   = .kba_int(dr[[8L]]),
    phev_n              = .kba_int(dr[[9L]]),
    hybrid_ohne_phev_n = .kba_int(dr[[10L]]),
    gas_n               = .kba_int(dr[[12L]]),
    wasserstoff_n       = .kba_int(dr[[13L]])
  ) |>
    dplyr::mutate(
      entity_name = entity_name,
      .after = berichtsmonat
    )
}

.kba_parse_fz28_kfz_fahrzeugarten <- function(raw, berichtsmonat, zeitraum = "monat") {
  .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "fahrzeugart",
    berichtsmonat = berichtsmonat,
    zeitraum = zeitraum
  ) |>
    dplyr::rename(fahrzeugart = entity)
}

.kba_parse_fz28_pkw_monate <- function(raw, berichtsmonat, zeitraum = "alle") {
  .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "monat",
    berichtsmonat = berichtsmonat,
    zeitraum = zeitraum
  ) |>
    dplyr::rename(monat = entity)
}

.kba_parse_fz28_pkw_halter <- function(raw, berichtsmonat, zeitraum = "monat") {
  .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "haltergruppe",
    berichtsmonat = berichtsmonat,
    zeitraum = zeitraum
  ) |>
    dplyr::rename(haltergruppe = entity)
}

.kba_parse_fz28_pkw_marken <- function(raw, berichtsmonat, zeitraum = "monat") {
  .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "marke",
    berichtsmonat = berichtsmonat,
    zeitraum = zeitraum
  ) |>
    dplyr::rename(marke = entity)
}

.kba_parse_fz28_pkw_segmente <- function(raw, berichtsmonat, zeitraum = "monat") {
  .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "segment",
    berichtsmonat = berichtsmonat,
    zeitraum = zeitraum
  ) |>
    dplyr::rename(segment = entity)
}

.kba_parse_fz28_pkw_bundeslaender <- function(raw, berichtsmonat, zeitraum = "monat") {
  parsed <- .kba_parse_fz28_alt_antrieb(
    raw,
    entity_name = "bundesland",
    berichtsmonat = berichtsmonat,
    keep_entities = .KBA_BUNDESLAENDER,
    zeitraum = zeitraum
  )

  if (nrow(parsed) == 0L) {
    return(parsed)
  }

  parsed |>
    dplyr::rename(bundesland = entity) |>
    dplyr::select(-entity_ebene)
}

# ── Hauptfunktion ────────────────────────────────────────────────────────────

#' KBA FZ28 – monatliche Neuzulassungen (alternative Antriebe)
#'
#' Liest eine lokale KBA-FZ28-Excel-Datei ein oder lädt die aktuellste Datei
#' von der KBA-Übersichtsseite. Die Tabellenblätter können sich über die Jahre
#' leicht unterscheiden; fehlende Sheets werden in `dir`-Modus übersprungen.
#'
#' @param type Auswertung, siehe Details.
#' @param file Pfad zu einer lokalen `.xlsx`-Datei.
#' @param dir Verzeichnis mit mehreren `fz28_*.xlsx`-Dateien.
#' @param verbose Fortschrittsmeldungen.
#' @param page_url KBA-Übersichtsseite mit Download-Links.
#' @param zeitraum Bei Tabellen mit Monats- und Jahresblock: `"monat"`,
#'   `"jahr_bisher"` oder `"alle"` (Standard: `"monat"`).
#' @return Tibble mit Neuzulassungszahlen.
#' @export
kba_neuzulassungen <- function(
    type     = c(
      "pkw_bundeslaender",
      "pkw_monate",
      "kfz_fahrzeugarten",
      "pkw_halter",
      "pkw_marken",
      "pkw_marken_jahr",
      "pkw_segmente"
    ),
    file     = NULL,
    dir      = NULL,
    verbose  = TRUE,
    page_url = .KBA_FZ28_PAGE_URL,
    zeitraum = c("monat", "jahr_bisher", "alle")
) {
  type <- match.arg(type)
  zeitraum <- match.arg(zeitraum)
  sheet <- .KBA_FZ28_SHEETS[[type]]

  if (!is.null(file) && !is.null(dir)) {
    cli::cli_abort("Bitte nur {.arg file} oder {.arg dir} angeben, nicht beides.")
  }

  parse_one <- function(f) {
    raw <- suppressMessages(
      readxl::read_excel(f, sheet = sheet, col_names = FALSE, col_types = "text")
    )
    berichtsmonat <- .kba_fz28_berichtsmonat_from_file(f)
    if (is.na(berichtsmonat)) {
      berichtsmonat <- .kba_fz28_berichtsmonat_from_raw(raw)
    }
    zr <- zeitraum
    result <- switch(type,
      kfz_fahrzeugarten = .kba_parse_fz28_kfz_fahrzeugarten(raw, berichtsmonat, zr),
      pkw_monate        = .kba_parse_fz28_pkw_monate(raw, berichtsmonat, zr),
      pkw_halter        = .kba_parse_fz28_pkw_halter(raw, berichtsmonat, zr),
      pkw_marken        = .kba_parse_fz28_pkw_marken(raw, berichtsmonat, zr),
      pkw_marken_jahr   = .kba_parse_fz28_pkw_marken(raw, berichtsmonat, "jahr_bisher"),
      pkw_segmente      = .kba_parse_fz28_pkw_segmente(raw, berichtsmonat, zr),
      pkw_bundeslaender = .kba_parse_fz28_pkw_bundeslaender(raw, berichtsmonat, zr)
    )
    if (nrow(result) > 0L && all(is.na(result$berichtsmonat))) {
      result$berichtsmonat <- berichtsmonat
    }
    result
  }

  if (!is.null(dir)) {
    if (!dir.exists(dir)) {
      cli::cli_abort("Verzeichnis nicht gefunden: {.file {dir}}")
    }
    files <- sort(list.files(dir, pattern = "^fz28.*\\.xlsx$", full.names = TRUE))
    if (length(files) == 0L) {
      cli::cli_abort("Keine fz28-*.xlsx in {.file {dir}} gefunden.")
    }

    if (verbose) {
      cli::cli_alert_info(
        "Lese {.strong {type}} ({sheet}) aus {length(files)} Datei(en) \u2026"
      )
    }

    results <- list()
    skipped <- 0L

    for (f in files) {
      available <- tryCatch(
        suppressMessages(readxl::excel_sheets(f)),
        error = function(e) character(0L)
      )
      if (!sheet %in% available) {
        if (verbose) {
          cli::cli_alert_warning(
            "  {.file {basename(f)}}: Sheet {.val {sheet}} fehlt \u2014 \u00fcbersprungen."
          )
        }
        skipped <- skipped + 1L
        next
      }
      parsed <- parse_one(f)
      if (nrow(parsed) == 0L) {
        if (verbose) {
          cli::cli_alert_warning(
            "  {.file {basename(f)}}: 0 Zeilen \u2014 \u00fcbersprungen."
          )
        }
        skipped <- skipped + 1L
        next
      }
      results[[basename(f)]] <- parsed
      if (verbose) {
        cli::cli_alert_success(
          "  {.file {basename(f)}}: {nrow(parsed)} Zeilen ({parsed$berichtsmonat[1L]})"
        )
      }
    }

    if (length(results) == 0L) {
      cli::cli_abort(
        c(
          "Keine kompatiblen FZ28-Dateien gefunden.",
          "i" = "Sheet {.val {sheet}} fehlt evtl. in \u00e4lteren Monatsdateien."
        )
      )
    }

    combined <- dplyr::bind_rows(results)
    if (verbose) {
      extra <- if (skipped > 0L) sprintf(" (%d \u00fcbersprungen)", skipped) else ""
      cli::cli_alert_success(
        "Fertig: {nrow(combined)} Zeilen aus {length(results)} Datei(en){extra}."
      )
    }
    return(combined)
  }

  use_tempfile <- FALSE
  if (is.null(file)) {
    urls       <- .kba_discover_xlsx_urls(page_url, verbose = verbose)
    latest_url <- urls[[1L]]
    fname      <- regmatches(latest_url, regexpr("[^/?]+\\.xlsx", latest_url))
    file       <- .kba_download_file(latest_url, label = fname, verbose = verbose)
    use_tempfile <- TRUE
    on.exit(try(unlink(file), silent = TRUE), add = TRUE)
  }

  if (!file.exists(file)) {
    cli::cli_abort("Datei nicht gefunden: {.file {file}}")
  }

  if (verbose) {
    cli::cli_h2("KBA FZ28 \u2014 {.strong {type}} ({sheet})")
    cli::cli_alert_info("Lese {.file {basename(file)}} \u2026")
  }

  result <- parse_one(file)

  if (nrow(result) == 0L) {
    cli::cli_abort(c(
      "Keine Daten geparst.",
      "i" = "Tabellenlayout von {.val {sheet}} evtl. ge\u00e4ndert."
    ))
  }

  if (verbose) {
    cli::cli_alert_success(
      "Fertig: {.strong {nrow(result)}} Zeilen \u00d7 {ncol(result)} Spalten."
    )
  }

  result
}

#' Alle KBA FZ28-Excel-Dateien herunterladen
#'
#' @param dir Zielverzeichnis.
#' @param overwrite Bestehende Dateien überschreiben?
#' @param verbose Fortschrittsmeldungen.
#' @param page_url KBA-Übersichtsseite.
#' @return Invisible character vector of local file paths.
#' @export
kba_download_fz28 <- function(
    dir       = "kba_fz28",
    overwrite = FALSE,
    verbose   = TRUE,
    page_url  = .KBA_FZ28_PAGE_URL
) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
    if (verbose) cli::cli_alert_info("Verzeichnis erstellt: {.file {dir}}")
  }

  urls <- .kba_discover_xlsx_urls(page_url, verbose = verbose)

  if (verbose) {
    cli::cli_alert_info(
      "Gefunden: {length(urls)} .xlsx-Datei{?en}. Starte Download \u2026"
    )
  }

  downloaded <- character(0L)

  for (url in urls) {
    fname <- regmatches(url, regexpr("[^/?]+\\.xlsx", url))
    dest  <- file.path(dir, fname)

    if (file.exists(dest) && !overwrite) {
      if (verbose) {
        cli::cli_alert_info("  {.file {fname}} bereits vorhanden \u2014 \u00fcbersprungen.")
      }
      downloaded <- c(downloaded, dest)
      next
    }

    resp <- tryCatch(
      httr::GET(url, httr::write_disk(dest, overwrite = TRUE)),
      error = function(e) {
        cli::cli_alert_warning(
          "Fehler beim Download von {.file {fname}}: {conditionMessage(e)}"
        )
        NULL
      }
    )

    if (!is.null(resp) && httr::status_code(resp) == 200L) {
      if (verbose) {
        cli::cli_alert_success(
          "  {.file {fname}} ({round(file.size(dest) / 1024)} KB)"
        )
      }
      downloaded <- c(downloaded, dest)
    } else if (!is.null(resp)) {
      cli::cli_alert_warning(
        "  HTTP {httr::status_code(resp)} f\u00fcr {.file {fname}} \u2014 \u00fcbersprungen."
      )
    }

    Sys.sleep(1)
  }

  if (verbose) {
    cli::cli_alert_success(
      "Fertig: {length(downloaded)}/{length(urls)} Datei{?en} in {.file {dir}}."
    )
  }

  invisible(downloaded)
}
