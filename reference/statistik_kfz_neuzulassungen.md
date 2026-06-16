# Kfz-Neuzulassungen nach Kraftstoffart oder Marke (aktuelles Jahr + Jahressummen)

Downloads and parses Kfz-Neuzulassungen data from the Statistik Austria
website. The source ODS file URL changes every month as new data is
published — the function always discovers the current URL dynamically
from the page so no manual link maintenance is needed.

## Usage

``` r
statistik_kfz_neuzulassungen(
  type = c("kraftstoff", "marken"),
  year = NULL,
  months = NULL,
  suppress_as_na = TRUE,
  verbose = TRUE,
  page_url =
    "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen"
)
```

## Arguments

- type:

  Character. One of `"kraftstoff"` (default) or `"marken"`.

- year:

  Integer scalar. The year to retrieve. `NULL` (default) uses the
  current year (monthly sheets). For `type = "kraftstoff"` you can also
  pass a past year, e.g. `2024` or `2025`, to get the corresponding
  annual ODS file. Historical files are only available for years listed
  on the Statistik Austria page (currently 2024–2025 for the Kraftstoff
  breakdown).

- months:

  Character vector of month sheet names to include, e.g.
  `c("Jänner", "Februar")`. `NULL` (default) returns all available
  sheets. Ignored when `year` refers to a historical annual file.

- suppress_as_na:

  Logical. If `TRUE` (default), suppressed cells (`"/"` in source,
  meaning n \< 5) become `NA`. If `FALSE` they become `0`.

- verbose:

  Logical. Print progress messages.

- page_url:

  The Statistik Austria page to discover ODS links from.

## Value

A `tibble` in long format. All counts are integer.

## Details

Two data types are available:

- `"kraftstoff"`:

  Neuzulassungen by fuel/energy type, vehicle type, and Bundesland.
  Current year returns monthly sheets; historical years return annual
  totals. Columns: `monat`, `bundesland`, `fahrzeugtyp`,
  `kraftstoffart`, `anzahl`.

- `"marken"`:

  Neuzulassungen by brand and vehicle type. Current year only (monthly
  sheets). Columns: `monat`, `marke`, `fahrzeugtyp`, `anzahl`. For PKW
  brand data since January 2000 use
  `statistik_get_pkw_neuzulassungen()`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Current year: monthly Elektro/Diesel/... breakdown per Bundesland
statistik_kfz_neuzulassungen("kraftstoff")

# Only Jänner and Februar, filtered to PKW and Wien
df <- statistik_kfz_neuzulassungen("kraftstoff", months = c("Jänner", "Februar"))
df[df$bundesland == "Wien" & df$fahrzeugtyp == "Personenkraftwagen Klasse M1", ]

# Historical annual Kraftstoff breakdown for 2025
statistik_kfz_neuzulassungen("kraftstoff", year = 2025)

# Current year: monthly brand × vehicle type
statistik_kfz_neuzulassungen("marken")

# For PKW brand data since 2000, use:
statistik_pkw_marken_zeitreihe(date_from = "2020-01")
} # }
```
