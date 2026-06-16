# Pkw-Neuzulassungen nach Marken ab Jänner 2000

Downloads the official Statistik Austria Open Data dataset
*Pkw-Neuzulassungen nach Marken ab Jänner 2000* (OGD ID:
`OGD_fkfzul0759_OD_PkwNZL_1`) via the OGD REST API and returns a tidy
long tibble with one row per brand × month combination.

## Usage

``` r
statistik_pkw_marken_zeitreihe(
  date_from = NULL,
  date_to = NULL,
  marken = NULL,
  parse_date = TRUE,
  verbose = TRUE
)
```

## Source

<https://data.statistik.gv.at/web/meta.jsp?dataset=OGD_fkfzul0759_OD_PkwNZL_1>

## Arguments

- date_from:

  Date or character `"YYYY-MM"`. Keep rows from this month onward.
  `NULL` (default) returns the full series from January 2000.

- date_to:

  Date or character `"YYYY-MM"`. Keep rows up to and including this
  month. `NULL` (default) returns all available data.

- marken:

  Character vector of brand names to keep (case-insensitive substring
  match against the Austrian brand label, e.g. `"VW"`,
  `c("BMW", "MERCEDES")`). `NULL` (default) returns all brands.

- parse_date:

  Logical. If `TRUE` (default), a `date` column of class `Date` (first
  day of each month) is added alongside `monat`.

- verbose:

  Logical. Print progress messages. Default `TRUE`.

## Value

A `tibble` with columns:

- `monat`:

  Austrian month label, e.g. `"Jänner 2000"`.

- `date`:

  `Date`: first day of the month (only when `parse_date = TRUE`).

- `brand`:

  Clean brand name without country code or internal code, e.g. `"VW"`.

- `producing_country`:

  ISO vehicle registration country code of the producing country, e.g.
  `"D"` for Germany.

- `is_ev_only`:

  Logical. `TRUE` if the brand sells only battery-electric vehicles
  (e.g. Tesla, NIO, Polestar).

- `marke`:

  Full brand label as published by Statistik Austria, e.g.
  `"VW (D) <040540>"`.

- `anzahl`:

  Integer count of new registrations.

## Details

The dataset covers new passenger car (Pkw) registrations in Austria by
brand and is updated monthly (typically around the 10th of the following
month). Dimension lookup CSVs are downloaded automatically on each call.

## Examples

``` r
if (FALSE) { # \dontrun{
# Full series, all brands
statistik_neuzulassungen_nach_marke()

# Since 2020, selected brands
statistik_neuzulassungen_nach_marke(
  date_from = "2020-01",
  marken    = c("VW", "SKODA", "BMW", "MERCEDES", "AUDI", "TESLA")
)

# Most recent 3 months, top 10 brands by registrations
df <- statistik_pkw_marken_zeitreihe(date_from = Sys.Date() - 100)
dplyr::slice_max(df, anzahl, by = monat, n = 10)
} # }
```
