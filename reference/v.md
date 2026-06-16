# Quickly View a Data Frame

A convenience wrapper around
[`DT::datatable()`](https://rdrr.io/pkg/DT/man/datatable.html) for fast,
nicely formatted interactive table previews. Numeric columns are
automatically rounded and alignment issues are handled via column
adjustment.

## Usage

``` r
v(
  df,
  title = NULL,
  digits = 1,
  n_rows = 25,
  font_size = "10px",
  header_font_size = "11px"
)
```

## Arguments

- df:

  A data frame (or tibble) to display.

- title:

  Character. An optional title for the table.

- digits:

  Integer. Number of decimal places for numeric columns. Defaults to 1.

- n_rows:

  The numbers of rows shown by default.

- font_size:

  Character. CSS font size for body cells. Defaults to `"10px"`.

- header_font_size:

  Character. CSS font size for column headers. Defaults to `"11px"`.

## Value

A [DT::datatable](https://rdrr.io/pkg/DT/man/datatable.html) widget.
