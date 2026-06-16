# Fetch the Power BI conceptual schema for an OCHA dataset

Retrieves column (property) names from the Power BI data model that
backs the OCHA casualties dashboards. Use the returned names with the
`filters` parameter of
[`un_ocha_fatalities`](https://robinkohrs.github.io/dav/reference/un_ocha_fatalities.md)
to build arbitrary column filters.

## Usage

``` r
un_ocha_get_schema(
  type = c("pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries"),
  table = NULL
)
```

## Arguments

- type:

  Character. Which dataset to query. One of `"pal_fatalities"`,
  `"isr_fatalities"`, `"pal_injuries"`, `"isr_injuries"`.

- table:

  Character. Optional table/entity name to filter to (e.g.
  `"vw_BS_Pal_Fatalities"`). If `NULL` (default) a named list is
  returned with one character vector of column names per table in the
  model.

## Value

A character vector when `table` is specified, or a named list of
character vectors (one per table) when `table = NULL`. Returns `NULL`
invisibly on failure.

## Examples

``` r
if (FALSE) { # \dontrun{
# All column names for the Palestinian fatalities entity
un_ocha_get_schema("pal_fatalities", table = "vw_BS_Pal_Fatalities")

# All tables in the model
names(un_ocha_get_schema("pal_fatalities"))
} # }
```
