# ============================================================================
# KBA Fahrzeugzulassungen – FZ 27
# Bestand an Kraftfahrzeugen und Kraftfahrzeuganhängern nach Bundesländern,
# Fahrzeugarten, Kraftstoffarten, Regionen
#
# Vollständige Sammlung aller Parser und Helper-Funktionen
# ============================================================================

# ── Konstanten ───────────────────────────────────────────────────────────────

.KBA_FZ27_PAGE_URL <- paste0(
  "https://www.kba.de/DE/Statistik/Produktkatalog/produkte/",
  "Fahrzeuge/fz27_b_uebersicht.html"
)
.KBA_BASE_URL <- "https://www.kba.de"

.KBA_DE_MONTHS <- c(
  Januar = 1L, Februar = 2L, "M\u00e4rz" = 3L, April = 4L,
  Mai = 5L, Juni = 6L, Juli = 7L, August = 8L,
  September = 9L, Oktober = 10L, November = 11L, Dezember = 12L
)

# Fahrzeugart labels for FZ 27.1 (data cols 2–12 after the "Land" col).
.KBA_FZ271_VARTYPES <- c(
  "Kraftr\u00e4der",
  "Personenkraftwagen",
  "Kraftomnibusse",
  "Lastkraftwagen",
  "Zugmaschinen insgesamt",
  "davon Sattelzugmaschinen",
  "davon sonstige Zugmaschinen",
  "davon land-/forstwirtschaftliche Zugmaschinen",
  "Sonstige Kfz",
  "Kraftfahrzeuganh\u00e4nger",
  "Fahrzeuge insgesamt"
)

# Fahrzeugart labels for FZ 27.2 (data cols 3–12 after "Land" and "Kraftstoffart")
.KBA_FZ272_VARTYPES <- c(
  "Kraftr\u00e4der",
  "Personenkraftwagen",
  "Kraftomnibusse",
  "Lastkraftwagen",
  "Zugmaschinen insgesamt",
  "davon Sattelzugmaschinen",
  "davon sonstige Zugmaschinen",
  "davon land-/forstwirtschaftliche Zugmaschinen",
  "Sonstige Kfz",
  "Kraftfahrzeuge insgesamt"
)

# Known Kraftstoffart values in FZ 27.2
.KBA_KRAFTSTOFFARTEN <- c(
  "Benzin", "Diesel", "Gas insgesamt",
  "Elektro (BEV)", "Hybrid insgesamt", "darunter Plug-in", "Sonstige"
)

# KBA renumbered sheets in Oct 2022:
#   FZ 27.5 (old: PKW×Emissionsgruppen) → dropped
#   FZ 27.6 (old: PKW×Haltergruppen)    → new FZ 27.5
#   FZ 27.7 (old: Nutzfahrzeuge×Gewicht) → new FZ 27.6
# For files before Oct 2022, these types live on the legacy sheet number.
.KBA_LEGACY_SHEETS <- c(pkw_halter = "FZ 27.6", nutzfahrzeuge_gewicht = "FZ 27.7")

# ── interne Helfer ───────────────────────────────────────────────────────────

.kba_int <- function(x) {
  x <- trimws(as.character(x))
  v <- suppressWarnings(as.integer(gsub("[^0-9]", "", x)))
  v[x %in% c("-", ".", "/", "")] <- NA_integer_
  v
}

.kba_num <- function(x) {
  x <- trimws(gsub(",", ".", as.character(x)))
  suppressWarnings(as.numeric(x))
}

.kba_fill_down <- function(x) {
  for (i in seq_along(x)[-1L]) {
    if (is.na(x[i])) x[i] <- x[i - 1L]
  }
  x
}

.kba_chr <- function(x) {
  v <- trimws(as.character(x))
  v[v == "NA" | v == ""] <- NA_character_
  v
}

.kba_stichtag_from_title <- function(raw) {
  txt <- paste(as.character(unlist(raw[5L, ])), collapse = " ")
  m <- regmatches(txt, regexpr(
    paste0("\\d{1,2}\\.\\s?(",
           "Januar|Februar|M\u00e4rz|April|Mai|Juni|",
           "Juli|August|September|Oktober|November|Dezember",
           ")\\s?\\d{4}"),
    txt
  ))
  if (length(m) == 0L) return(as.Date(NA))
  parts <- strsplit(trimws(gsub("\\s+", " ", m)), " ")[[1L]]
  day   <- as.integer(gsub("\\.", "", parts[1L]))
  month <- unname(.KBA_DE_MONTHS[parts[2L]])
  year  <- as.integer(parts[3L])
  as.Date(sprintf("%04d-%02d-%02d", year, month, day))
}

.kba_parse_date <- function(x) {
  x <- trimws(as.character(x))
  d <- as.Date(x, format = "%d.%m.%Y")
  nas <- is.na(d)
  if (any(nas)) d[nas] <- as.Date(x[nas], format = "%Y-%m-%d")
  d
}

.kba_download_file <- function(url, label = NULL, verbose = TRUE) {
  if (verbose && !is.null(label)) cli::cli_alert_info("Downloading {.file {label}}...")
  tmp <- tempfile(fileext = ".xlsx")
  resp <- tryCatch(
    httr::GET(url, httr::write_disk(tmp, overwrite = TRUE)),
    error = function(e) cli::cli_abort("Download failed: {conditionMessage(e)}")
  )
  if (httr::status_code(resp) != 200L) {
    cli::cli_abort("HTTP {httr::status_code(resp)} for {url}")
  }
  if (verbose) cli::cli_alert_success("  {round(file.size(tmp) / 1024)} KB")
  tmp
}

.kba_discover_xlsx_urls <- function(page_url, verbose = TRUE) {
  if (verbose) cli::cli_alert_info("Fetching KBA FZ27 overview page...")
  page <- tryCatch(
    rvest::read_html(page_url),
    error = function(e) cli::cli_abort("Could not reach KBA page: {conditionMessage(e)}")
  )
  hrefs <- page |>
    rvest::html_nodes("a") |>
    rvest::html_attr("href")
  hrefs <- unique(hrefs[!is.na(hrefs) & grepl("\\.xlsx", hrefs)])
  if (length(hrefs) == 0L) {
    cli::cli_abort(c(
      "No .xlsx files found on the KBA FZ27 page.",
      "i" = "The page structure may have changed. Check: {.url {page_url}}"
    ))
  }
  ifelse(startsWith(hrefs, "http"), hrefs,
         paste0(.KBA_BASE_URL, hrefs))
}

# ── sheet parsers ───────────────────────────────────────────────────────────

.kba_parse_bundesland <- function(raw) {
  stichtag   <- .kba_stichtag_from_title(raw)
  data_rows  <- raw[8:25, ]
  bundesland <- .kba_chr(data_rows[[1L]])

  result <- lapply(seq_along(.KBA_FZ271_VARTYPES), function(j) {
    tibble::tibble(
      stichtag    = stichtag,
      bundesland  = bundesland,
      fahrzeugart = .KBA_FZ271_VARTYPES[j],
      anzahl      = .kba_int(data_rows[[j + 1L]])
    )
  })
  dplyr::bind_rows(result) |> dplyr::arrange(.data$bundesland, .data$fahrzeugart)
}

.kba_parse_bundesland_kraftstoff <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows  <- raw[8:nrow(raw), ]
  col1      <- .kba_chr(all_rows[[1L]])
  col2      <- .kba_chr(all_rows[[2L]])

  keep      <- !is.na(col2) & col2 %in% .KBA_KRAFTSTOFFARTEN
  data_rows <- all_rows[keep, ]
  col1_k    <- .kba_fill_down(col1[keep])
  col2_k    <- col2[keep]

  n_types <- min(length(.KBA_FZ272_VARTYPES), ncol(data_rows) - 2L)
  result <- lapply(seq_len(n_types), function(j) {
    tibble::tibble(
      stichtag      = stichtag,
      bundesland    = col1_k,
      kraftstoffart = col2_k,
      fahrzeugart   = .KBA_FZ272_VARTYPES[j],
      anzahl        = .kba_int(data_rows[[j + 2L]])
    )
  })
  dplyr::bind_rows(result) |>
    dplyr::arrange(.data$bundesland, .data$kraftstoffart, .data$fahrzeugart)
}

.kba_parse_pkw_quartale <- function(raw) {
  all_rows <- raw[12:nrow(raw), ]
  is_date  <- grepl("^\\d{2}\\.\\d{2}\\.\\d{4}$", trimws(as.character(all_rows[[1L]])))
  dr       <- all_rows[is_date, ]

  tibble::tibble(
    stichtag          = .kba_parse_date(dr[[1L]]),
    pkw_insgesamt     = .kba_int(dr[[2L]]),
    alt_antriebe_n    = .kba_int(dr[[3L]]),
    alt_antriebe_pct  = .kba_num(dr[[4L]]),
    elektro_n         = .kba_int(dr[[5L]]),
    elektro_pct       = .kba_num(dr[[6L]]),
    bev_n             = .kba_int(dr[[7L]]),
    fcev_n            = .kba_int(dr[[8L]]),
    phev_n            = .kba_int(dr[[9L]]),
    hybrid_n          = .kba_int(dr[[10L]]),
    benzin_hybrid_n   = .kba_int(dr[[11L]]),
    diesel_hybrid_n   = .kba_int(dr[[12L]]),
    gas_n             = .kba_int(dr[[13L]]),
    wasserstoff_n     = .kba_int(dr[[14L]])
  ) |> dplyr::arrange(.data$stichtag)
}

.kba_parse_pkw_marken <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[12:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])

  keep <- !is.na(col1) & !grepl("Kraftfahrt-Bundesamt|Hinweis|Deutschland|^INSGESAMT$", col1)
  dr   <- all_rows[keep, ]

  tibble::tibble(
    stichtag         = stichtag,
    marke            = .kba_chr(dr[[1L]]),
    pkw_insgesamt    = .kba_int(dr[[2L]]),
    alt_antriebe_n   = .kba_int(dr[[3L]]),
    alt_antriebe_pct = .kba_num(dr[[4L]]),
    elektro_n        = .kba_int(dr[[5L]]),
    elektro_pct      = .kba_num(dr[[6L]]),
    bev_n            = .kba_int(dr[[7L]]),
    fcev_n           = .kba_int(dr[[8L]]),
    phev_n           = .kba_int(dr[[9L]]),
    hybrid_n         = .kba_int(dr[[10L]]),
    benzin_hybrid_n  = .kba_int(dr[[11L]]),
    diesel_hybrid_n  = .kba_int(dr[[12L]]),
    gas_n            = .kba_int(dr[[13L]]),
    wasserstoff_n    = .kba_int(dr[[14L]])
  ) |> dplyr::arrange(.data$marke)
}

.kba_parse_pkw_segmente <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[12:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])

  # FZ 27.10 embeds two year-blocks: current year then previous year.
  # Identify the date-label rows ("1. Januar YYYY") that head each block.
  date_rows <- which(grepl("^\\d+\\. \\w+ \\d{4}$", col1) & !is.na(col1))
  start <- if (length(date_rows) >= 1L) date_rows[1L] + 1L else 1L
  end   <- if (length(date_rows) >= 2L) date_rows[2L] - 1L else length(col1)
  keep  <- start:end
  keep  <- keep[!is.na(col1[keep]) & !grepl("Kraftfahrt-Bundesamt|Hinweis", col1[keep])]
  dr    <- all_rows[keep, ]

  tibble::tibble(
    stichtag         = stichtag,
    segment          = .kba_chr(dr[[1L]]),
    pkw_insgesamt    = .kba_int(dr[[2L]]),
    alt_antriebe_n   = .kba_int(dr[[3L]]),
    alt_antriebe_pct = .kba_num(dr[[4L]]),
    elektro_n        = .kba_int(dr[[5L]]),
    elektro_pct      = .kba_num(dr[[6L]]),
    bev_n            = .kba_int(dr[[7L]]),
    fcev_n           = .kba_int(dr[[8L]]),
    phev_n           = .kba_int(dr[[9L]]),
    hybrid_n         = .kba_int(dr[[10L]]),
    benzin_hybrid_n  = .kba_int(dr[[11L]]),
    diesel_hybrid_n  = .kba_int(dr[[12L]]),
    gas_n            = .kba_int(dr[[13L]]),
    wasserstoff_n    = .kba_int(dr[[14L]])
  ) |> dplyr::arrange(.data$segment)
}

.kba_parse_pkw_halter <- function(raw) {
  # Guard: pre-Oct 2022 files placed a different sheet at "FZ 27.5" (PKW × Emissionsgruppen).
  # The correct halter sheet has "Haltergruppe" in row 7, col 2.
  if (nrow(raw) < 7L || !grepl("Halter", as.character(raw[[2L]][7L]), ignore.case = TRUE)) {
    return(dplyr::tibble())
  }
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[8:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])
  col2     <- .kba_chr(all_rows[[2L]])

  # Three row types per Bundesland:
  #   gewerblich: col2 contains "Gewerbliche"
  #   privat:     col2 contains "Private"
  #   alle:       col1 ends in " zusammen" (includes vehicles with unknown halter)
  is_gew   <- !is.na(col2) & grepl("Gewerbliche", col2)
  is_priv  <- !is.na(col2) & grepl("Private",     col2)
  is_zus   <- !is.na(col1) & grepl(" zusammen$",  col1) & is.na(col2)

  # Exclude everything from the Deutschland block onward.
  # "Deutschland insgesamt" is the last zusammen row — cut before its preceding halter rows.
  de_zus_idx <- which(!is.na(col1) & grepl("Deutschland", col1))
  cutoff     <- if (length(de_zus_idx) > 0L) de_zus_idx[1L] else (length(col1) + 1L)
  in_range   <- seq_along(col1) < cutoff

  keep   <- (is_gew | is_priv | is_zus) & in_range
  dr     <- all_rows[keep, ]
  col1_k <- col1[keep]
  col2_k <- col2[keep]

  # Bundesland: fill down then strip " zusammen" suffix
  bl <- .kba_fill_down(col1_k)
  bl <- sub(" zusammen$", "", bl)

  halter_lbl <- dplyr::case_when(
    grepl("Gewerbliche", col2_k) ~ "gewerblich",
    grepl("Private",     col2_k) ~ "privat",
    TRUE                         ~ "alle"
  )

  kraftstoffe <- c("Benzin", "Diesel", "Gas insgesamt", "Elektro (BEV)",
                   "Hybrid insgesamt", "darunter Plug-in", "Sonstige")

  result <- lapply(seq_along(kraftstoffe), function(i) {
    tibble::tibble(
      stichtag      = stichtag,
      bundesland    = bl,
      halter        = halter_lbl,
      kraftstoffart = kraftstoffe[i],
      anzahl        = .kba_int(dr[[i + 2L]])
    )
  })

  # col 10 = Personenkraftwagen insgesamt (direct total, incl. unknown halter in "alle" rows)
  pkw_total <- tibble::tibble(
    stichtag      = stichtag,
    bundesland    = bl,
    halter        = halter_lbl,
    kraftstoffart = "Personenkraftwagen insgesamt",
    anzahl        = .kba_int(dr[[10L]])
  )

  dplyr::bind_rows(c(result, list(pkw_total))) |>
    dplyr::arrange(.data$bundesland, .data$halter, .data$kraftstoffart)
}

.kba_parse_pkw_emissionen <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[8:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])
  col2     <- .kba_chr(all_rows[[2L]])

  keep <- !is.na(col2) & col2 %in% .KBA_KRAFTSTOFFARTEN
  data_rows <- all_rows[keep, ]
  bl        <- .kba_fill_down(col1[keep])
  kraftstoff <- col2[keep]

  emi_cols <- c("Euro 1", "Euro 2", "Euro 3", "Euro 4", "Euro 5",
                "Euro 6 insgesamt", "darunter Euro 6d-temp", "darunter Euro 6d",
                "Sonstige")
  result <- lapply(seq_along(emi_cols), function(i) {
    tibble::tibble(
      stichtag       = stichtag,
      bundesland     = bl,
      kraftstoffart  = kraftstoff,
      emissionsklasse = emi_cols[i],
      anzahl         = .kba_int(data_rows[[i + 2L]])
    )
  })
  dplyr::bind_rows(result) |>
    dplyr::arrange(.data$bundesland, .data$kraftstoffart, .data$emissionsklasse)
}

.kba_parse_kfz_emissionen <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[8:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])
  col2     <- .kba_chr(all_rows[[2L]])

  is_emission <- !is.na(col2) & grepl("^(Euro|Sonstige)", col2)
  data_rows   <- all_rows[is_emission, ]
  bl         <- .kba_fill_down(col1[is_emission])
  emi        <- col2[is_emission]

  result <- lapply(seq_along(.KBA_FZ271_VARTYPES), function(j) {
    tibble::tibble(
      stichtag      = stichtag,
      bundesland    = bl,
      emissionsklasse = emi,
      fahrzeugart   = .KBA_FZ271_VARTYPES[j],
      anzahl        = .kba_int(data_rows[[j + 2L]])
    )
  })
  dplyr::bind_rows(result) |>
    dplyr::arrange(.data$bundesland, .data$emissionsklasse, .data$fahrzeugart)
}

.kba_parse_nutzfahrzeuge_gewicht <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[8:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])
  col2     <- .kba_chr(all_rows[[2L]])

  is_weight <- !is.na(col2) & grepl("kg$", col2)
  data_rows <- all_rows[is_weight, ]
  bl        <- .kba_fill_down(col1[is_weight])
  gewicht   <- col2[is_weight]

  emi_cols <- c("Euro 1/S1", "Euro 2/S2", "Euro 3/S3", "Euro 4/S4",
                "Euro 5/S5", "Euro 6/S6", "Sonstige", "Insgesamt")
  result <- lapply(seq_along(emi_cols), function(i) {
    tibble::tibble(
      stichtag       = stichtag,
      bundesland     = bl,
      gewichtsklasse = gewicht,
      emissionsklasse = emi_cols[i],
      anzahl         = .kba_int(data_rows[[i + 2L]])
    )
  })
  dplyr::bind_rows(result) |>
    dplyr::arrange(.data$bundesland, .data$gewichtsklasse, .data$emissionsklasse)
}

.kba_parse_kfz_alter <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[8:nrow(raw), ]
  col1     <- .kba_chr(all_rows[[1L]])
  col2     <- .kba_chr(all_rows[[2L]])

  is_age <- !is.na(col1) & grepl("(unter|bis|und mehr|Jahre)", col1)
  data_rows <- all_rows[is_age, ]
  altersklasse <- col1[is_age]
  kraftstoff   <- .kba_fill_down(col2[is_age])

  result <- lapply(seq_along(.KBA_FZ272_VARTYPES), function(j) {
    tibble::tibble(
      stichtag      = stichtag,
      altersklasse  = altersklasse,
      kraftstoffart = kraftstoff,
      fahrzeugart   = .KBA_FZ272_VARTYPES[j],
      anzahl        = .kba_int(data_rows[[j + 2L]])
    )
  })
  dplyr::bind_rows(result) |>
    dplyr::arrange(.data$altersklasse, .data$kraftstoffart, .data$fahrzeugart)
}

.kba_parse_pkw_kreise <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[12:nrow(raw), ]
  col2     <- .kba_chr(all_rows[[2L]])

  keep <- !is.na(col2) & grepl("^\\d{5}$", col2)
  dr   <- all_rows[keep, ]

  bl <- .kba_fill_down(.kba_chr(dr[[1L]]))

  tibble::tibble(
    stichtag          = stichtag,
    bundesland        = bl,
    kennziffer        = .kba_chr(dr[[2L]]),
    zulassungsbezirk  = .kba_chr(dr[[3L]]),
    pkw_insgesamt     = .kba_int(dr[[4L]]),
    alt_antriebe_n    = .kba_int(dr[[5L]]),
    alt_antriebe_pct  = .kba_num(dr[[6L]]),
    elektro_n         = .kba_int(dr[[7L]]),
    elektro_pct       = .kba_num(dr[[8L]]),
    bev_n             = .kba_int(dr[[9L]]),
    phev_n            = .kba_int(dr[[10L]]),
    hybrid_n          = .kba_int(dr[[11L]]),
    benzin_hybrid_n   = .kba_int(dr[[12L]]),
    diesel_hybrid_n   = .kba_int(dr[[13L]]),
    gas_n             = .kba_int(dr[[14L]])
  ) |> dplyr::arrange(.data$bundesland, .data$kennziffer)
}

.kba_parse_pkw_plz <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[11:nrow(raw), ]
  col1     <- trimws(as.character(all_rows[[1L]]))

  keep     <- grepl("^\\d{5}$", col1)
  dr       <- all_rows[keep, ]
  plz      <- trimws(as.character(dr[[1L]]))

  dplyr::bind_rows(
    tibble::tibble(
      stichtag      = stichtag,
      plz           = plz,
      halter        = "gewerblich",
      pkw_insgesamt = .kba_int(dr[[2L]]),
      bev_n         = .kba_int(dr[[3L]]),
      phev_n        = .kba_int(dr[[4L]])
    ),
    tibble::tibble(
      stichtag      = stichtag,
      plz           = plz,
      halter        = "privat",
      pkw_insgesamt = .kba_int(dr[[5L]]),
      bev_n         = .kba_int(dr[[6L]]),
      phev_n        = .kba_int(dr[[7L]])
    )
  ) |> dplyr::arrange(.data$plz, .data$halter)
}

.kba_parse_pkw_gemeinden <- function(raw) {
  stichtag <- .kba_stichtag_from_title(raw)
  all_rows <- raw[11:nrow(raw), ]
  col3     <- .kba_chr(all_rows[[3L]])

  keep <- !is.na(col3)
  dr   <- all_rows[keep, ]

  bl <- .kba_fill_down(.kba_chr(dr[[1L]]))
  zb_raw <- .kba_fill_down(.kba_chr(dr[[2L]]))

  kreis_schluessel  <- substr(zb_raw, 1L, 5L)
  zulassungsbezirk  <- trimws(substr(zb_raw, 6L, nchar(zb_raw)))

  dplyr::bind_rows(
    tibble::tibble(
      stichtag         = stichtag,
      bundesland       = bl,
      kreis_schluessel = kreis_schluessel,
      zulassungsbezirk = zulassungsbezirk,
      gemeinde         = .kba_chr(dr[[3L]]),
      halter           = "gewerblich",
      pkw_insgesamt    = .kba_int(dr[[4L]]),
      bev_n            = .kba_int(dr[[5L]]),
      phev_n           = .kba_int(dr[[6L]])
    ),
    tibble::tibble(
      stichtag         = stichtag,
      bundesland       = bl,
      kreis_schluessel = kreis_schluessel,
      zulassungsbezirk = zulassungsbezirk,
      gemeinde         = .kba_chr(dr[[3L]]),
      halter           = "privat",
      pkw_insgesamt    = .kba_int(dr[[7L]]),
      bev_n            = .kba_int(dr[[8L]]),
      phev_n           = .kba_int(dr[[9L]])
    )
  ) |> dplyr::arrange(.data$bundesland, .data$kreis_schluessel, .data$gemeinde, .data$halter)
}

# ── Hauptfunktion: kba_bestand ───────────────────────────────────────────────

#' KBA FZ27 Bestand – Fahrzeugbestand nach verschiedenen Merkmalen
#'
#' Liest eine lokale KBA FZ27-Excel-Datei ein (Quartalsdaten, Bestand an
#' Kraftfahrzeugen) und gibt die gewünschten Daten als aufgeräumtes Tibble
#' zurück. Wird kein `file` angegeben, wird automatisch die aktuellste Datei
#' von der KBA-Website heruntergeladen.
#'
#' @param type Character. Auswahl der Auswertung.
#' @param file Character oder `NULL`. Pfad zu einer lokalen Excel-Datei.
#' @param dir Character oder `NULL`. Verzeichnis mit mehreren Dateien.
#' @param verbose Logical. Fortschrittsmeldungen.
#' @param page_url URL der KBA-Übersichtsseite.
#' @return Tibble mit den angeforderten Daten.
#' @export
kba_bestand <- function(
    type     = c("bundesland", "bundesland_kraftstoff",
                 "pkw_quartale", "pkw_marken", "pkw_segmente",
                 "pkw_halter", "pkw_emissionen", "kfz_emissionen",
                 "nutzfahrzeuge_gewicht", "kfz_alter",
                 "pkw_kreise", "pkw_plz", "pkw_gemeinden"),
    file     = NULL,
    dir      = NULL,
    verbose  = TRUE,
    page_url = .KBA_FZ27_PAGE_URL
) {
  type <- match.arg(type)

  if (!is.null(file) && !is.null(dir)) {
    cli::cli_abort("Bitte nur {.arg file} oder {.arg dir} angeben, nicht beides.")
  }

  # ── Directory mode ────────────────────────────────────────────────────────
  if (!is.null(dir)) {
    if (!dir.exists(dir)) {
      cli::cli_abort("Verzeichnis nicht gefunden: {.file {dir}}")
    }
    files <- sort(list.files(dir, pattern = "^fz27.*\\.xlsx$", full.names = TRUE))
    if (length(files) == 0L) {
      cli::cli_abort("Keine .xlsx-Dateien in {.file {dir}} gefunden.")
    }

    sheet <- c(
      bundesland            = "FZ 27.1",
      bundesland_kraftstoff = "FZ 27.2",
      pkw_quartale          = "FZ 27.9",
      pkw_marken            = "FZ 27.11",
      pkw_segmente          = "FZ 27.10",
      pkw_halter            = "FZ 27.5",
      pkw_emissionen        = "FZ 27.4",
      kfz_emissionen        = "FZ 27.3",
      nutzfahrzeuge_gewicht = "FZ 27.6",
      kfz_alter             = "FZ 27.7",
      pkw_kreise            = "FZ 27.15",
      pkw_plz               = "FZ 27.16",
      pkw_gemeinden         = "FZ 27.17"
    )[[type]]

    n_files <- length(files)
    if (verbose) {
      cli::cli_alert_info(
        "Lese {.strong {type}} ({sheet}) aus {n_files} Datei(en) in {.file {dir}} \u2026"
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
            "  {.file {basename(f)}}: Sheet {.val {sheet}} nicht vorhanden — übersprungen."
          )
        }
        skipped <- skipped + 1L
        next
      }
      raw <- suppressMessages(
        readxl::read_excel(f, sheet = sheet, col_names = FALSE, col_types = "text")
      )
      parsed <- switch(type,
        bundesland            = .kba_parse_bundesland(raw),
        bundesland_kraftstoff = .kba_parse_bundesland_kraftstoff(raw),
        pkw_quartale          = .kba_parse_pkw_quartale(raw),
        pkw_marken            = .kba_parse_pkw_marken(raw),
        pkw_segmente          = .kba_parse_pkw_segmente(raw),
        pkw_halter            = .kba_parse_pkw_halter(raw),
        pkw_emissionen        = .kba_parse_pkw_emissionen(raw),
        kfz_emissionen        = .kba_parse_kfz_emissionen(raw),
        nutzfahrzeuge_gewicht = .kba_parse_nutzfahrzeuge_gewicht(raw),
        kfz_alter             = .kba_parse_kfz_alter(raw),
        pkw_kreise            = .kba_parse_pkw_kreise(raw),
        pkw_plz               = .kba_parse_pkw_plz(raw),
        pkw_gemeinden         = .kba_parse_pkw_gemeinden(raw)
      )
      # Legacy sheet fallback: KBA renumbered FZ 27.5/6/7 in Oct 2022.
      # If primary sheet returns 0 rows, retry with the pre-2022 sheet number.
      if (nrow(parsed) == 0L && type %in% names(.KBA_LEGACY_SHEETS)) {
        legacy_sh <- .KBA_LEGACY_SHEETS[[type]]
        if (legacy_sh %in% available) {
          raw <- suppressMessages(
            readxl::read_excel(f, sheet = legacy_sh, col_names = FALSE, col_types = "text")
          )
          parsed <- switch(type,
            pkw_halter            = .kba_parse_pkw_halter(raw),
            nutzfahrzeuge_gewicht = .kba_parse_nutzfahrzeuge_gewicht(raw)
          )
        }
      }
      if (nrow(parsed) == 0L) {
        if (verbose) {
          cli::cli_alert_warning(
            "  {.file {basename(f)}}: 0 Zeilen geparst — Dateistruktur unbekannt, übersprungen."
          )
        }
        skipped <- skipped + 1L
        next
      }
      results[[basename(f)]] <- parsed
      if (verbose) {
        cli::cli_alert_success(
          "  {.file {basename(f)}}: {nrow(parsed)} Zeilen ({parsed$stichtag[1L]})"
        )
      }
    }

    if (length(results) == 0L) {
      cli::cli_abort(
        c("Keine kompatiblen Dateien gefunden.",
          "i" = "Sheet {.val {sheet}} ist erst ab bestimmten Quartalsdateien verfügbar.",
          "i" = "Für FZ 27.15 (pkw_kreise): ab 01.01.2022.",
          "i" = "Für FZ 27.16/17 (pkw_plz / pkw_gemeinden): ab 01.10.2022.")
      )
    }

    combined <- dplyr::bind_rows(results)
    if (verbose) {
      n_ok  <- length(results)
      extra <- if (skipped > 0L) sprintf(" (%d \u00fcbersprungen)", skipped) else ""
      cli::cli_alert_success(
        "Fertig: {nrow(combined)} Zeilen aus {n_ok} Datei(en){extra}."
      )
    }
    return(combined)
  }

  # ── Single-file mode ──────────────────────────────────────────────────────
  sheet_map <- c(
    bundesland            = "FZ 27.1",
    bundesland_kraftstoff = "FZ 27.2",
    pkw_quartale          = "FZ 27.9",
    pkw_marken            = "FZ 27.11",
    pkw_segmente          = "FZ 27.10",
    pkw_halter            = "FZ 27.5",
    pkw_emissionen        = "FZ 27.4",
    kfz_emissionen        = "FZ 27.3",
    nutzfahrzeuge_gewicht = "FZ 27.6",
    kfz_alter             = "FZ 27.7",
    pkw_kreise            = "FZ 27.15",
    pkw_plz               = "FZ 27.16",
    pkw_gemeinden         = "FZ 27.17"
  )
  sheet <- sheet_map[[type]]

  if (verbose) {
    cli::cli_h2("KBA FZ27 Bestand \u2014 {.strong {type}} ({sheet})")

    if (startsWith(type, "pkw_")) {
      cli::cli_alert_info(
        "Datenbasis: {.strong PKW (Personenkraftwagen) only}."
      )
    } else {
      cli::cli_alert_warning(
        "Datenbasis: {.strong Alle Kraftfahrzeuge (Kfz)} \u2014 nicht nur PKW!"
      )
    }

    if (type %in% c("pkw_plz", "pkw_gemeinden")) {
      cli::cli_alert_warning(
        "Dieses Sheet enth\u00e4lt {.strong nur BEV und Plug-in-Hybrid (PHEV)}."
      )
    }
  }

  # Herunterladen, falls keine Datei angegeben
  use_tempfile <- FALSE
  if (is.null(file)) {
    urls         <- .kba_discover_xlsx_urls(page_url, verbose = verbose)
    latest_url   <- urls[[1L]]
    fname        <- regmatches(latest_url, regexpr("[^/?]+\\.xlsx", latest_url))
    file         <- .kba_download_file(latest_url, label = fname, verbose = verbose)
    use_tempfile <- TRUE
    on.exit(try(unlink(file), silent = TRUE), add = TRUE)
  }

  if (!file.exists(file)) {
    cli::cli_abort("Datei nicht gefunden: {.file {file}}")
  }

  if (verbose) {
    cli::cli_alert_info("Lese Tabellenblatt {.val {sheet}} aus {.file {basename(file)}} \u2026")
  }

  raw <- suppressMessages(
    readxl::read_excel(file, sheet = sheet, col_names = FALSE, col_types = "text")
  )

  result <- switch(type,
    bundesland            = .kba_parse_bundesland(raw),
    bundesland_kraftstoff = .kba_parse_bundesland_kraftstoff(raw),
    pkw_quartale          = .kba_parse_pkw_quartale(raw),
    pkw_marken            = .kba_parse_pkw_marken(raw),
    pkw_segmente          = .kba_parse_pkw_segmente(raw),
    pkw_halter            = .kba_parse_pkw_halter(raw),
    pkw_emissionen        = .kba_parse_pkw_emissionen(raw),
    kfz_emissionen        = .kba_parse_kfz_emissionen(raw),
    nutzfahrzeuge_gewicht = .kba_parse_nutzfahrzeuge_gewicht(raw),
    kfz_alter             = .kba_parse_kfz_alter(raw),
    pkw_kreise            = .kba_parse_pkw_kreise(raw),
    pkw_plz               = .kba_parse_pkw_plz(raw),
    pkw_gemeinden         = .kba_parse_pkw_gemeinden(raw)
  )

  # Legacy sheet fallback: KBA renumbered FZ 27.5/6/7 in Oct 2022.
  if (nrow(result) == 0L && type %in% names(.KBA_LEGACY_SHEETS)) {
    legacy_sh      <- .KBA_LEGACY_SHEETS[[type]]
    available_file <- tryCatch(suppressMessages(readxl::excel_sheets(file)), error = function(e) character(0L))
    if (legacy_sh %in% available_file) {
      if (verbose) cli::cli_alert_warning("Fallback auf Legacy-Sheet {.val {legacy_sh}} (Datei vor Okt. 2022).")
      raw    <- suppressMessages(readxl::read_excel(file, sheet = legacy_sh, col_names = FALSE, col_types = "text"))
      result <- switch(type,
        pkw_halter            = .kba_parse_pkw_halter(raw),
        nutzfahrzeuge_gewicht = .kba_parse_nutzfahrzeuge_gewicht(raw)
      )
    }
  }

  if (verbose) {
    cli::cli_alert_success(
      "Fertig: {.strong {nrow(result)}} Zeilen \u00d7 {ncol(result)} Spalten."
    )
  }

  result
}

# ── Download-Funktion ───────────────────────────────────────────────────────

#' Alle KBA FZ27-Excel-Dateien herunterladen
#'
#' @param dir Zielverzeichnis.
#' @param overwrite Überschreiben?
#' @param verbose Fortschrittsmeldungen.
#' @param page_url URL der Übersichtsseite.
#' @return Unsichtbarer Vektor mit Pfaden.
#' @export
kba_download_fz27 <- function(
    dir      = "kba_fz27",
    overwrite = FALSE,
    verbose   = TRUE,
    page_url  = .KBA_FZ27_PAGE_URL
) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
    if (verbose) cli::cli_alert_info("Verzeichnis erstellt: {.file {dir}}")
  }

  urls <- .kba_discover_xlsx_urls(page_url, verbose = verbose)

  if (verbose) {
    cli::cli_alert_info(
      "Gefunden: {length(urls)} .xlsx-Datei{?en}. Starte Download\u2026"
    )
  }

  downloaded <- character(0L)

  for (url in urls) {
    fname <- regmatches(url, regexpr("[^/?]+\\.xlsx", url))
    dest  <- file.path(dir, fname)

    if (file.exists(dest) && !overwrite) {
      if (verbose) cli::cli_alert_info("  {.file {fname}} bereits vorhanden \u2014 \u00fcbersprungen.")
      downloaded <- c(downloaded, dest)
      next
    }

    resp <- tryCatch({
      httr::GET(url, httr::write_disk(dest, overwrite = TRUE))
    }, error = function(e) {
      cli::cli_alert_warning("Fehler beim Download von {.file {fname}}: {conditionMessage(e)}")
      NULL
    })

    if (!is.null(resp) && httr::status_code(resp) == 200L) {
      if (verbose) {
        cli::cli_alert_success("  {.file {fname}} ({round(file.size(dest)/1024)} KB)")
      }
      downloaded <- c(downloaded, dest)
    } else if (!is.null(resp)) {
      cli::cli_alert_warning("  HTTP {httr::status_code(resp)} f\u00fcr {.file {fname}} \u2014 \u00fcbersprungen.")
    }

    Sys.sleep(1)  # be polite to the KBA server
  }

  if (verbose) {
    cli::cli_alert_success(
      "Fertig: {length(downloaded)}/{length(urls)} Datei{?en} in {.file {dir}}."
    )
  }

  invisible(downloaded)
}

# ── Helper-Funktionen für den Datenjournalismus ──────────────────────────────

#' BEV-Bestand (absolut)
#'
#' @param geo "bundesland", "kreis", "plz", "gemeinde"
#' @param halter "alle", "privat", "gewerblich" (nur für PLZ/Gemeinde)
#' @param file Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).
#' @param dir Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).
#' @param ... Weitere Argumente an [kba_bestand()].
#' @return Tibble mit `stichtag`, `geo_code`, `geo_name`, `bev_bestand`
#' @export
kba_bev_bestand <- function(geo = c("bundesland", "kreis", "plz", "gemeinde"),
                            halter = c("alle", "privat", "gewerblich"),
                            file = NULL, dir = NULL, ...) {
  geo <- match.arg(geo)
  halter <- match.arg(halter)

  type <- switch(geo,
    bundesland = "bundesland_kraftstoff",
    kreis      = "pkw_kreise",
    plz        = "pkw_plz",
    gemeinde   = "pkw_gemeinden"
  )

  dat <- kba_bestand(type, file = file, dir = dir, ...)

  result <- switch(geo,
    bundesland = {
      dat |>
        dplyr::filter(fahrzeugart == "Personenkraftwagen", kraftstoffart == "Elektro (BEV)") |>
        dplyr::select(stichtag, bundesland, anzahl) |>
        dplyr::rename(geo_name = bundesland, bev_bestand = anzahl) |>
        dplyr::mutate(geo_code = NA_character_, .before = geo_name)
    },
    kreis = {
      dat |>
        dplyr::select(stichtag, bundesland, kennziffer, zulassungsbezirk, bev_n) |>
        dplyr::rename(geo_code = kennziffer, geo_name = zulassungsbezirk, bev_bestand = bev_n) |>
        dplyr::mutate(bundesland = NULL)
    },
    plz = {
      if (halter != "alle") {
        dat <- dat |> dplyr::filter(halter == !!halter)
      } else {
        dat <- dat |>
          dplyr::group_by(stichtag, plz) |>
          dplyr::summarise(bev_bestand = sum(bev_n, na.rm = TRUE), .groups = "drop") |>
          dplyr::mutate(halter = "alle")
      }
      dat |>
        dplyr::select(stichtag, plz, halter, bev_bestand) |>
        dplyr::rename(geo_code = plz) |>
        dplyr::mutate(geo_name = geo_code)
    },
    gemeinde = {
      if (halter != "alle") {
        dat <- dat |> dplyr::filter(halter == !!halter)
      } else {
        dat <- dat |>
          dplyr::group_by(stichtag, bundesland, kreis_schluessel, zulassungsbezirk, gemeinde) |>
          dplyr::summarise(bev_bestand = sum(bev_n, na.rm = TRUE), .groups = "drop") |>
          dplyr::mutate(halter = "alle")
      }
      dat |>
        dplyr::select(stichtag, bundesland, kreis_schluessel, zulassungsbezirk, gemeinde, halter, bev_bestand) |>
        dplyr::rename(geo_code = kreis_schluessel, geo_name = gemeinde)
    }
  )

  result
}

#' BEV-Anteil (%)
#'
#' @inheritParams kba_bev_bestand
#' @return Tibble mit zusätzlicher Spalte `bev_anteil_pct`
#' @export
kba_bev_anteil <- function(geo = c("bundesland", "kreis", "plz", "gemeinde"),
                           halter = c("alle", "privat", "gewerblich"),
                           file = NULL, dir = NULL, ...) {
  geo <- match.arg(geo)
  halter <- match.arg(halter)

  type <- switch(geo,
    bundesland = "pkw_halter",   # FZ 27.5: Bundesland + Halter + PKW insgesamt
    kreis      = "pkw_kreise",
    plz        = "pkw_plz",
    gemeinde   = "pkw_gemeinden"
  )

  if (geo == "kreis" && halter != "alle") {
    cli::cli_warn(c(
      "Das Sheet {.val FZ 27.15} (pkw_kreise) enth\u00e4lt keine Halter-Aufschl\u00fcsselung.",
      "i" = "Das Argument {.code halter = \"{halter}\"} wird ignoriert \u2014 Ergebnis zeigt alle Halter.",
      "i" = "F\u00fcr eine Halter-Aufschl\u00fcsselung nutze {.code geo = \"plz\"} oder {.code geo = \"gemeinde\"}."
    ))
  }

  dat <- kba_bestand(type, file = file, dir = dir, ...)

  result <- switch(geo,
    bundesland = {
      # "Personenkraftwagen insgesamt" column from FZ 27.5 = authoritative total
      total <- dat |>
        dplyr::filter(halter        == !!halter,
                      kraftstoffart == "Personenkraftwagen insgesamt") |>
        dplyr::select(stichtag, bundesland, pkw_insgesamt = anzahl)
      bev <- dat |>
        dplyr::filter(halter        == !!halter,
                      kraftstoffart == "Elektro (BEV)") |>
        dplyr::select(stichtag, bundesland, bev_n = anzahl)
      total |>
        dplyr::left_join(bev, by = c("stichtag", "bundesland")) |>
        dplyr::mutate(
          bev_anteil_pct = 100 * bev_n / pkw_insgesamt,
          geo_code       = NA_character_,
          geo_name       = bundesland
        ) |>
        dplyr::select(stichtag, geo_code, geo_name, bev_anteil_pct)
    },
    kreis = {
      dat |>
        dplyr::mutate(
          bev_anteil_pct = 100 * bev_n / pkw_insgesamt
        ) |>
        dplyr::select(stichtag, bundesland, kennziffer, zulassungsbezirk, bev_anteil_pct) |>
        dplyr::rename(geo_code = kennziffer, geo_name = zulassungsbezirk)
    },
    plz = {
      if (halter != "alle") {
        dat <- dat |> dplyr::filter(halter == !!halter)
      } else {
        dat <- dat |>
          dplyr::group_by(stichtag, plz) |>
          dplyr::summarise(
            pkw_insgesamt = sum(pkw_insgesamt, na.rm = TRUE),
            bev_n = sum(bev_n, na.rm = TRUE),
            .groups = "drop"
          ) |>
          dplyr::mutate(halter = "alle")
      }
      dat |>
        dplyr::mutate(bev_anteil_pct = 100 * bev_n / pkw_insgesamt) |>
        dplyr::select(stichtag, plz, halter, bev_anteil_pct) |>
        dplyr::rename(geo_code = plz) |>
        dplyr::mutate(geo_name = geo_code)
    },
    gemeinde = {
      if (halter != "alle") {
        dat <- dat |> dplyr::filter(halter == !!halter)
      } else {
        dat <- dat |>
          dplyr::group_by(stichtag, bundesland, kreis_schluessel, zulassungsbezirk, gemeinde) |>
          dplyr::summarise(
            pkw_insgesamt = sum(pkw_insgesamt, na.rm = TRUE),
            bev_n = sum(bev_n, na.rm = TRUE),
            .groups = "drop"
          ) |>
          dplyr::mutate(halter = "alle")
      }
      dat |>
        dplyr::mutate(bev_anteil_pct = 100 * bev_n / pkw_insgesamt) |>
        dplyr::select(stichtag, bundesland, kreis_schluessel, zulassungsbezirk,
                      gemeinde, halter, bev_anteil_pct) |>
        dplyr::rename(geo_code = kreis_schluessel, geo_name = gemeinde)
    }
  )

  result
}

#' Emissionsklassen (Euro-Normen) für PKW
#'
#' @param bundesland Optional einschränken auf ein Bundesland.
#' @param file Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).
#' @param dir Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).
#' @param ... Weitere Argumente an [kba_bestand()].
#' @return Tibble mit `stichtag`, `bundesland`, `kraftstoffart`, `emissionsklasse`, `anzahl`
#' @export
kba_emissionsklassen <- function(bundesland = NULL, file = NULL, dir = NULL, ...) {
  dat <- kba_bestand("pkw_emissionen", file = file, dir = dir, ...)

  if (!is.null(bundesland)) {
    dat <- dat |> dplyr::filter(.data$bundesland == .env$bundesland)
  }

  dat
}

#' Antriebsmix für eine Fahrzeugart (alle Kfz)
#'
#' @param fahrzeugart Eine der Fahrzeugarten aus FZ 27.2, z.B. "Personenkraftwagen"
#' @param bundesland Optional einschränken.
#' @param file Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).
#' @param dir Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).
#' @param ... Weitere Argumente an [kba_bestand()].
#' @return Tibble mit `stichtag`, `bundesland`, `kraftstoffart`, `anzahl`
#' @export
kba_antriebsmix <- function(fahrzeugart = "Personenkraftwagen",
                            bundesland = NULL,
                            file = NULL, dir = NULL, ...) {
  dat <- kba_bestand("bundesland_kraftstoff", file = file, dir = dir, ...) |>
    dplyr::filter(.data$fahrzeugart == .env$fahrzeugart)

  if (!is.null(bundesland)) {
    dat <- dat |> dplyr::filter(.data$bundesland == .env$bundesland)
  }

  dat |>
    dplyr::select(stichtag, bundesland, kraftstoffart, anzahl)
}

#' SUV- und Geländewagen-Anteil (Proxy für Gewichtszunahme)
#'
#' @param file Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).
#' @param dir Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).
#' @param ... Weitere Argumente an [kba_bestand()].
#' @return Tibble mit `stichtag`, `suv_gelaende_anteil_pct`
#' @export
kba_suv_anteil <- function(file = NULL, dir = NULL, ...) {
  dat <- kba_bestand("pkw_segmente", file = file, dir = dir, ...)

  suv_segs <- c("SUVs", "Gel\u00e4ndewagen")

  total <- dat |>
    dplyr::summarise(pkw_insgesamt = sum(pkw_insgesamt, na.rm = TRUE), .by = stichtag)
  suv   <- dat |>
    dplyr::filter(segment %in% suv_segs) |>
    dplyr::summarise(suv_gelaende = sum(pkw_insgesamt, na.rm = TRUE), .by = stichtag)
  dplyr::left_join(total, suv, by = "stichtag") |>
    dplyr::mutate(suv_gelaende_anteil_pct = 100 * suv_gelaende / pkw_insgesamt) |>
    dplyr::select(stichtag, suv_gelaende_anteil_pct)
}

#' Zeitreihe über mehrere Quartale (nur für Bundesland/Kreis)
#'
#' @param geo "bundesland" oder "kreis"
#' @param antrieb "bev", "phev", "hybrid", "gas", "diesel"
#' @param dir Verzeichnis mit mehreren Dateien (erforderlich)
#' @param ... weitere Argumente an `kba_bestand`
#' @return Tibble mit `stichtag`, `geo_code`, `geo_name`, `bestand`
#' @export
kba_zeitreihe <- function(geo = c("bundesland", "kreis"),
                          antrieb = c("bev", "phev", "hybrid", "gas", "diesel"),
                          dir = NULL, ...) {
  geo <- match.arg(geo)
  antrieb <- match.arg(antrieb)

  if (is.null(dir)) {
    cli::cli_abort("F\u00fcr Zeitreihen muss {.arg dir} angegeben werden (Verzeichnis mit mehreren Dateien).")
  }

  if (geo == "bundesland") {
    dat <- kba_bestand("bundesland_kraftstoff", dir = dir, ...) |>
      dplyr::filter(.data$fahrzeugart == "Personenkraftwagen")

    # Kraftstoffart zuordnen
    kf_map <- c(bev = "Elektro (BEV)", phev = "darunter Plug-in",
                hybrid = "Hybrid insgesamt", gas = "Gas insgesamt",
                diesel = "Diesel")
    kf_art <- kf_map[[antrieb]]

    if (antrieb == "phev") {
      # PHEV ist eine Teilmenge von Hybrid – Vorsicht bei der Summierung
      dat <- dat |> dplyr::filter(.data$kraftstoffart == kf_art)
    } else {
      dat <- dat |> dplyr::filter(.data$kraftstoffart == kf_art)
    }

    dat |>
      dplyr::group_by(.data$stichtag, .data$bundesland) |>
      dplyr::summarise(bestand = sum(.data$anzahl, na.rm = TRUE), .groups = "drop") |>
      dplyr::rename(geo_name = bundesland) |>
      dplyr::mutate(geo_code = NA_character_, .before = geo_name)

  } else { # kreis
    dat <- kba_bestand("pkw_kreise", dir = dir, ...)

    bestand_col <- switch(antrieb,
      bev = "bev_n",
      phev = "phev_n",
      hybrid = "hybrid_n",
      gas = "gas_n",
      diesel = NULL   # diesel nicht direkt in pkw_kreise verfügbar
    )

    if (is.null(bestand_col)) {
      cli::cli_abort("Antrieb {.val {antrieb}} ist in Kreisdaten nicht verf\u00fcgbar. Verwende 'bev', 'phev', 'hybrid' oder 'gas'.")
    }

    dat |>
      dplyr::group_by(.data$stichtag, .data$kennziffer, .data$zulassungsbezirk) |>
      dplyr::summarise(
        bestand = sum(.data[[bestand_col]], na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::rename(geo_code = kennziffer, geo_name = zulassungsbezirk)
  }
}

#' BEV-Bestand nach Kreisen (spezialisiert)
#'
#' @inheritParams kba_bev_bestand
#' @return Tibble mit `stichtag`, `kreis_schluessel`, `zulassungsbezirk`, `bundesland`, `bev_bestand`
#' @export
kba_bev_kreise <- function(file = NULL, dir = NULL, ...) {
  dat <- kba_bestand("pkw_kreise", file = file, dir = dir, ...)
  dat |>
    dplyr::select(stichtag, bundesland, kennziffer, zulassungsbezirk, bev_n) |>
    dplyr::rename(kreis_schluessel = kennziffer, bev_bestand = bev_n)
}

#' BEV-Bestand nach PLZ
#'
#' @inheritParams kba_bev_bestand
#' @return Tibble mit `stichtag`, `plz`, `halter`, `bev_bestand`, `phev_bestand`
#' @export
kba_bev_plz <- function(halter = c("alle", "privat", "gewerblich"),
                        file = NULL, dir = NULL, ...) {
  halter <- match.arg(halter)
  dat <- kba_bestand("pkw_plz", file = file, dir = dir, ...)

  if (halter == "alle") {
    dat <- dat |>
      dplyr::group_by(stichtag, plz) |>
      dplyr::summarise(
        bev_bestand = sum(bev_n, na.rm = TRUE),
        phev_bestand = sum(phev_n, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(halter = "alle")
  } else {
    dat <- dat |> dplyr::filter(halter == !!halter)
    dat <- dat |> dplyr::rename(bev_bestand = bev_n, phev_bestand = phev_n)
  }

  dat
}

#' BEV-Bestand nach Gemeinden
#'
#' @inheritParams kba_bev_bestand
#' @return Tibble mit `stichtag`, `bundesland`, `kreis_schluessel`, `zulassungsbezirk`, `gemeinde`, `halter`, `bev_bestand`, `phev_bestand`
#' @export
kba_bev_gemeinden <- function(halter = c("alle", "privat", "gewerblich"),
                              file = NULL, dir = NULL, ...) {
  halter <- match.arg(halter)
  dat <- kba_bestand("pkw_gemeinden", file = file, dir = dir, ...)

  if (halter == "alle") {
    dat <- dat |>
      dplyr::group_by(stichtag, bundesland, kreis_schluessel, zulassungsbezirk, gemeinde) |>
      dplyr::summarise(
        bev_bestand = sum(bev_n, na.rm = TRUE),
        phev_bestand = sum(phev_n, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(halter = "alle")
  } else {
    dat <- dat |> dplyr::filter(halter == !!halter)
    dat <- dat |> dplyr::rename(bev_bestand = bev_n, phev_bestand = phev_n)
  }

  dat
}

# ── Absolute Bestands-Wrapper ────────────────────────────────────────────────

.kba_halter_warn <- function(geo, halter) {
  # bundesland supports halter via FZ 27.5; only kreis lacks the split
  if (geo == "kreis" && halter != "alle") {
    cli::cli_warn(c(
      "{.code geo = \"kreis\"} enth\u00e4lt keine Halter-Aufschl\u00fcsselung (FZ 27.15).",
      "i" = "{.arg halter} wird ignoriert \u2014 Ergebnis zeigt alle Halter.",
      "i" = "F\u00fcr eine Halter-Aufschl\u00fcsselung nutze {.code geo = \"plz\"} oder {.code geo = \"gemeinde\"}."
    ))
  }
}

#' Absoluter BEV-Bestand
#'
#' @param geo "bundesland", "kreis", "plz", "gemeinde"
#' @param halter "alle", "privat", "gewerblich" (nur PLZ/Gemeinde)
#' @param file,dir,... weitergereicht an [kba_bestand()]
#' @return Tibble mit `bev_n`
#' @export
kba_bev_n <- function(geo    = c("bundesland", "kreis", "plz", "gemeinde"),
                      halter = c("alle", "privat", "gewerblich"),
                      file = NULL, dir = NULL, ...) {
  geo    <- match.arg(geo)
  halter <- match.arg(halter)
  .kba_halter_warn(geo, halter)

  type <- switch(geo,
    bundesland = "pkw_halter",   # FZ 27.5: Bundesland + Halter + alle Kraftstoffarten
    kreis      = "pkw_kreise",
    plz        = "pkw_plz",
    gemeinde   = "pkw_gemeinden"
  )
  dat <- kba_bestand(type, file = file, dir = dir, ...)

  switch(geo,
    bundesland = {
      dat |>
        dplyr::filter(halter        == !!halter,
                      kraftstoffart == "Elektro (BEV)") |>
        dplyr::select(stichtag, bundesland, halter, bev_n = anzahl)
    },
    kreis = {
      dat |>
        dplyr::select(stichtag, bundesland, kennziffer, zulassungsbezirk, bev_n)
    },
    plz = {
      if (halter == "alle") {
        dat |>
          dplyr::summarise(bev_n = sum(bev_n, na.rm = TRUE),
                           .by = c(stichtag, plz)) |>
          dplyr::mutate(halter = "alle")
      } else {
        dat |>
          dplyr::filter(halter == !!halter) |>
          dplyr::select(stichtag, plz, halter, bev_n)
      }
    },
    gemeinde = {
      by_cols <- c("stichtag", "bundesland", "kreis_schluessel", "zulassungsbezirk", "gemeinde")
      if (halter == "alle") {
        dat |>
          dplyr::summarise(bev_n = sum(bev_n, na.rm = TRUE), .by = dplyr::all_of(by_cols)) |>
          dplyr::mutate(halter = "alle")
      } else {
        dat |>
          dplyr::filter(halter == !!halter) |>
          dplyr::select(dplyr::all_of(c(by_cols, "halter", "bev_n")))
      }
    }
  )
}

#' Absoluter Nicht-BEV-Bestand (alle PKW ohne reine Elektro)
#'
#' @inheritParams kba_bev_n
#' @return Tibble mit `nicht_bev_n` (= pkw_insgesamt - bev_n, inkl. PHEV/Hybrid/Verbrenner)
#' @export
kba_non_bev_n <- function(geo    = c("bundesland", "kreis", "plz", "gemeinde"),
                          halter = c("alle", "privat", "gewerblich"),
                          file = NULL, dir = NULL, ...) {
  geo    <- match.arg(geo)
  halter <- match.arg(halter)
  .kba_halter_warn(geo, halter)

  type <- switch(geo,
    bundesland = "pkw_halter",   # FZ 27.5: has PKW insgesamt directly, supports halter
    kreis      = "pkw_kreise",
    plz        = "pkw_plz",
    gemeinde   = "pkw_gemeinden"
  )
  dat <- kba_bestand(type, file = file, dir = dir, ...)

  switch(geo,
    bundesland = {
      # "Personenkraftwagen insgesamt" row = authoritative total (incl. unknown halter in "alle")
      total <- dat |>
        dplyr::filter(halter        == !!halter,
                      kraftstoffart == "Personenkraftwagen insgesamt") |>
        dplyr::select(stichtag, bundesland, halter, pkw_n = anzahl)
      bev <- dat |>
        dplyr::filter(halter        == !!halter,
                      kraftstoffart == "Elektro (BEV)") |>
        dplyr::select(stichtag, bundesland, bev_n = anzahl)
      total |>
        dplyr::left_join(bev, by = c("stichtag", "bundesland")) |>
        dplyr::mutate(nicht_bev_n = pkw_n - bev_n) |>
        dplyr::select(stichtag, bundesland, halter, nicht_bev_n)
    },
    kreis = {
      dat |>
        dplyr::mutate(nicht_bev_n = pkw_insgesamt - bev_n) |>
        dplyr::select(stichtag, bundesland, kennziffer, zulassungsbezirk, nicht_bev_n)
    },
    plz = {
      by_cols <- c("stichtag", "plz")
      if (halter == "alle") {
        dat |>
          dplyr::summarise(
            pkw_insgesamt = sum(pkw_insgesamt, na.rm = TRUE),
            bev_n         = sum(bev_n,         na.rm = TRUE),
            .by = dplyr::all_of(by_cols)
          ) |>
          dplyr::mutate(halter = "alle", nicht_bev_n = pkw_insgesamt - bev_n) |>
          dplyr::select(dplyr::all_of(c(by_cols, "halter", "nicht_bev_n")))
      } else {
        dat |>
          dplyr::filter(halter == !!halter) |>
          dplyr::mutate(nicht_bev_n = pkw_insgesamt - bev_n) |>
          dplyr::select(dplyr::all_of(c(by_cols, "halter", "nicht_bev_n")))
      }
    },
    gemeinde = {
      by_cols <- c("stichtag", "bundesland", "kreis_schluessel", "zulassungsbezirk", "gemeinde")
      if (halter == "alle") {
        dat |>
          dplyr::summarise(
            pkw_insgesamt = sum(pkw_insgesamt, na.rm = TRUE),
            bev_n         = sum(bev_n,         na.rm = TRUE),
            .by = dplyr::all_of(by_cols)
          ) |>
          dplyr::mutate(halter = "alle", nicht_bev_n = pkw_insgesamt - bev_n) |>
          dplyr::select(dplyr::all_of(c(by_cols, "halter", "nicht_bev_n")))
      } else {
        dat |>
          dplyr::filter(halter == !!halter) |>
          dplyr::mutate(nicht_bev_n = pkw_insgesamt - bev_n) |>
          dplyr::select(dplyr::all_of(c(by_cols, "halter", "nicht_bev_n")))
      }
    }
  )
}