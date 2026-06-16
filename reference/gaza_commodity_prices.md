# Download and Process Gaza Commodity Price Data

Downloads commodity price data for Gaza from the Humanitarian Data
Exchange (HDX), processes it into a tidy format, and can translate
commodity names to German.

## Usage

``` r
gaza_commodity_prices(translate_names = TRUE)
```

## Arguments

- translate_names:

  Logical. If `TRUE` (default), attempts to translate commodity names to
  German using `polyglotr::google_translate`. Requires the `polyglotr`
  package. If `FALSE` or `polyglotr` is not available,
  `commodity_name_german` will be `NA`.

## Value

A tibble with processed commodity price data. Columns include:

- `commodity_name_english`: Original commodity name in English.

- `commodity_name_german`: Translated commodity name in German (or NA if
  translation off/failed).

- `date`: The date of the price observation.

- `absolute_price`: The price of the commodity.

## Details

Gaza Commodity Prices

The function fetches the Excel file from the "State of Palestine - Price
of basic commodities in Gaza" dataset on HDX. It cleans the column
names, identifies relevant commodity and price columns, and pivots the
data into a long format. Dates are parsed: one special column
representing October 2023 data is assigned `2023-10-01`, and others are
derived from Excel serial date numbers present in column headers (e.g.,
"Nov-23" becomes `x45231` then `2023-11-01`). Commodity names (English)
can be translated. The output is a tibble with columns:
`commodity_name_english`, `commodity_name_german` (optional), `date`,
and `absolute_price`.

## Examples

``` r
if (FALSE) { # \dontrun{
  try({
    gaza_prices = gaza_commodity_prices()
    print(head(gaza_prices))

    # Example if polyglotr is not installed or translation is off:
    # gaza_prices_no_translate = gaza_commodity_prices(translate_names = FALSE)
    # print(head(gaza_prices_no_translate))
  }, error = function(e) {
    message("Error in example: ", e$message)
    message("This might be due to network issues, API limits, or changes in data source.")
  })
} # }
```
