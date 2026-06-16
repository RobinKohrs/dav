# Discover the distinct values of a filterable column in an OCHA Power BI report

Sends a "populate-dropdown" query to the Power BI API and returns all
distinct non-null values for the requested column. Use this *before*
building filtered queries to learn the exact strings to pass to the
filter arguments.

## Usage

``` r
un_ocha_fetch_filter_values(
  type = c("pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries"),
  col
)
```

## Arguments

- type:

  Character. Which dashboard to query. Same values as in
  [`un_ocha_fatalities`](https://robinkohrs.github.io/dav/reference/un_ocha_fatalities.md),
  excluding `"all"`.

- col:

  Character. The column *Property* name to fetch values for (e.g.
  `"Hostilities"`, `"Area"`, `"Weapon_name (groups)"`). Note: use the
  property name, not any display alias.

## Value

A one-column tibble of distinct non-null values, limited to 1,000.

## Examples

``` r
if (FALSE) { # \dontrun{
# What hostility-type strings exist in Palestinian Fatalities?
un_ocha_fetch_filter_values("pal_fatalities", "Hostilities")

# Area values (property "Area", displayed as "Region"):
un_ocha_fetch_filter_values("pal_fatalities", "Area")

# Weapon types:
un_ocha_fetch_filter_values("pal_fatalities", "Weapon_name (groups)")

# Poc_Period values for Palestinian Injuries:
un_ocha_fetch_filter_values("pal_injuries", "Poc_Period")
} # }
```
