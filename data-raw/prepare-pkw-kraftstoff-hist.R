## data-raw/prepare-pkw-kraftstoff-hist.R
## Processes the Statistik Austria Excel (2006-2025) into a tidy tibble
## and saves it as data/at_pkw_kraftstoff_hist.rda
##
## Re-run this script whenever an updated Excel is received.

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
})

REGIONS <- c(
  "Burgenland", "Kärnten", "Niederösterreich", "Oberösterreich",
  "Salzburg", "Steiermark", "Tirol", "Vorarlberg", "Wien", "Zusammen"
)

MONTH_NUM <- c(
  Jänner = 1L, Februar = 2L, März = 3L, April = 4L,
  Mai = 5L, Juni = 6L, Juli = 7L, August = 8L,
  September = 9L, Oktober = 10L, November = 11L, Dezember = 12L
)

fp <- system.file(
  "extdata", "at_pkw_kraftstoff_hist_2006_2025.xlsx",
  package = "davR"
)
if (!nzchar(fp)) {
  # fall back to local path when running from data-raw/ directly
  fp <- here::here(
    "inst", "extdata", "at_pkw_kraftstoff_hist_2006_2025.xlsx"
  )
}

raw <- suppressMessages(
  read_excel(fp, col_names = FALSE, skip = 5)
)

# ---- Reconstruct column names ----
# Row 1: year appears once per 13-column block (at block start, i.e. every 13th col)
# Row 2: month names (or NA for col 1 = Category)
# Structure: [Category | Jan..Dez,Zusammen | Jan..Dez,Zusammen | ...]
n_data_cols     <- ncol(raw) - 1L
months_per_year <- 13L  # 12 months + annual "Zusammen"
n_years         <- n_data_cols %/% months_per_year

# Extract years from row 1 (one non-NA per block)
year_vals <- as.integer(as.character(unlist(raw[1, ])))
year_vals <- year_vals[!is.na(year_vals)]
stopifnot(length(year_vals) == n_years)

years_vec  <- rep(year_vals, each = months_per_year)
months_vec <- as.character(unlist(raw[2, 2:(1 + n_years * months_per_year)]))

col_names <- c("Category", paste(years_vec, months_vec, sep = "_"))
colnames(raw) <- col_names[seq_len(ncol(raw))]

# ---- Clean body ----
body <- raw[-c(1, 2), ]
body$Category <- trimws(as.character(body$Category))

# Drop footer / source row
body <- body[!is.na(body$Category) & body$Category != "NA" &
               !grepl("^Q\\s", body$Category), ]

# ---- Assign Bundesland and Fuel_Type ----
bundesland_v <- character(nrow(body))
current_bl   <- NA_character_
for (i in seq_len(nrow(body))) {
  if (body$Category[i] %in% REGIONS) {
    current_bl <- body$Category[i]
  }
  bundesland_v[i] <- current_bl
}
body$bundesland <- bundesland_v

# Remove the Bundesland header rows themselves (they have no numeric data)
body <- body[!body$Category %in% REGIONS, ]
body <- body[nzchar(body$Category), ]

# ---- Pivot to long ----
# Keep only individual month columns (not "Zusammen" annual totals)
keep_cols <- c("bundesland", "Category",
               names(body)[grepl("_", names(body)) &
                             !grepl("_Zusammen$", names(body))])

body <- body[, keep_cols]

long <- tidyr::pivot_longer(
  body,
  cols      = -c(bundesland, Category),
  names_to  = "year_month",
  values_to = "anzahl_raw"
)

at_pkw_kraftstoff_hist <- long |>
  dplyr::transmute(
    bundesland   = bundesland,
    kraftstoffart = trimws(as.character(Category)),
    year  = as.integer(sub("_.*$", "", year_month)),
    month = MONTH_NUM[sub("^[0-9]+_", "", year_month)],
    date  = as.Date(sprintf("%d-%02d-01", year, month)),
    anzahl = suppressWarnings(as.integer(anzahl_raw))
  ) |>
  dplyr::filter(!is.na(month), !is.na(bundesland)) |>
  # Harmonise: "Zusammen" → "Österreich" to match ODS nomenclature
  dplyr::mutate(
    bundesland = dplyr::if_else(bundesland == "Zusammen", "Österreich", bundesland)
  ) |>
  dplyr::arrange(bundesland, kraftstoffart, date) |>
  tibble::as_tibble()

cat(sprintf(
  "at_pkw_kraftstoff_hist: %d rows | %d bundesland | %d kraftstoff | %s to %s\n",
  nrow(at_pkw_kraftstoff_hist),
  length(unique(at_pkw_kraftstoff_hist$bundesland)),
  length(unique(at_pkw_kraftstoff_hist$kraftstoffart)),
  min(at_pkw_kraftstoff_hist$date),
  max(at_pkw_kraftstoff_hist$date)
))

usethis::use_data(at_pkw_kraftstoff_hist, overwrite = TRUE)
