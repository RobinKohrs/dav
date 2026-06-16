# Historical Pkw-Neuzulassungen by Bundesland and Kraftstoffart (2006–2025)

Monthly counts of new Pkw (passenger car) registrations in Austria,
broken down by Bundesland and fuel/drive type, covering January 2006 to
December 2025. The data were provided by Statistik Austria as a special
evaluation and are bundled in the package for offline access.

## Usage

``` r
at_pkw_kraftstoff_hist
```

## Format

A tibble with 22,560 rows and 5 columns:

- `bundesland`:

  Austrian state (`"Burgenland"`, ..., `"Wien"`, `"Österreich"` for the
  national total).

- `kraftstoffart`:

  Fuel/drive type, e.g. `"Benzin"`, `"Diesel"`, `"Elektro"`,
  `"Benzin/Elektro (hybrid)"`, etc.

- `year`:

  Integer year.

- `month`:

  Integer month (1–12).

- `date`:

  `Date`: first day of the month.

- `anzahl`:

  Integer count of new registrations (`NA` = suppressed due to small
  cell size).

## Source

Statistik Austria, special evaluation provided per request. License: CC
BY 4.0.

## Details

Combine with the live data from `statistik_get_kraftstoff_timeseries()`
to extend the series through the current year.
