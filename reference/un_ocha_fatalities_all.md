# Fetch all OCHA casualty records with every available categorical dimension

Returns a flat tibble with one row per unique combination of categorical
dimensions (Date, Area, Governorate, perpetrator affiliation,
nationality, etc.) plus the total count for that combination. Use this
when you want to filter and aggregate the data yourself instead of
relying on server-side grouping.

## Usage

``` r
un_ocha_fatalities_all(
  type = "pal_fatalities",
  filters = NULL,
  date_range = NULL,
  debug_dsr = FALSE
)
```

## Arguments

- type:

  Character. One of `"pal_fatalities"`, `"pal_injuries"`,
  `"isr_fatalities"`, `"isr_injuries"`.

- filters:

  Named list of additional column → value(s) filters, identical to the
  `filters` argument of
  [`un_ocha_fatalities`](https://robinkohrs.github.io/dav/reference/un_ocha_fatalities.md).

## Value

A tibble. The exact columns depend on `type`. `Date` is always an R
`Date`. The count column is named after the underlying measure (`Fat`,
`Inj`, `Fatalities`, `Injuries`).

## Examples

``` r
if (FALSE) { # \dontrun{
all_pal_fat  <- un_ocha_fatalities_all("pal_fatalities")
all_pal_inj  <- un_ocha_fatalities_all("pal_injuries")
all_isr_fat  <- un_ocha_fatalities_all("isr_fatalities")
all_isr_inj  <- un_ocha_fatalities_all("isr_injuries")

# Filter yourself after fetching
all_pal_fat |>
  dplyr::filter(Area == "West Bank", `Doer Aff. (groups)` == "Civilian-settler")
} # }
```
