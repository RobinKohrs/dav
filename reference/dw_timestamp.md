# Create a Formatted Timestamp String

Generates a timestamp string with specific formatting options, focusing
on German natural language formats (e.g., "9. Dezember um 7:20 Uhr").

## Usage

``` r
dw_timestamp(x = Sys.time(), format = "de_text", tz = "")
```

## Arguments

- x:

  A `POSIXct`, `POSIXt`, or `Date` object. Defaults to
  [`Sys.time()`](https://rdrr.io/r/base/Sys.time.html).

- format:

  A character string specifying the format. Options include:

  - `"de_text"`: "9. Dezember um 7:20 Uhr" (Default)

  - `"de_date"`: "9. Dezember 2025"

  - `"de_short"`: "09.12.2025"

  - Any valid standard format string (e.g., `"%Y-%m-%d"`).

- tz:

  Timezone specification to be used for the conversion, if available.
  Defaults to the timezone attribute of `x` or system default. You can
  pass, e.g., "Europe/Vienna".

## Value

A character string of the formatted date.

## Examples

``` r
dw_timestamp()
#> [1] "16. Juni um 14:01 Uhr"
dw_timestamp(format = "de_date")
#> [1] "16. Juni 2026"
```
