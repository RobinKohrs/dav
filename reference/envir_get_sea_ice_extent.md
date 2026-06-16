# Download Arctic/Antarctic Sea Ice Extent Data

Fetches daily sea ice extent data from the National Snow and Ice Data
Center (NSIDC) REST API
<https://nsidc.org/arcticseaicenews/charctic-interactive-sea-ice-graph/>.
Allows specifying years, pole (North/Arctic or South/Antarctic), and
optionally applying a smoothing window. Also retrieves the 1981-2010
quantile data (median, IQR, range) for comparison, applying the same
smoothing if specified.

## Usage

``` r
envir_get_sea_ice_extent(years = NULL, pole = "north", window = 5)
```

## Arguments

- years:

  A numeric vector of years for which to retrieve daily data.

- pole:

  Character string: `"north"` (default) for Arctic or `"south"` for
  Antarctic.

- window:

  Numeric: The size of the moving average smoothing window (days).
  Defaults to `5`. Set `window = 1` to retrieve raw, unsmoothed data.
  Must be a positive integer.

## Value

A tidy data frame with the following columns:

- `date`: The date (as `Date` objects). For yearly data, this is the
  actual date. For quantile data, this is the day-of-year mapped onto
  the base year 2000 (a leap year) for consistent plotting.

- `ice_extent_mi_sqkm`: Sea ice extent in millions of square kilometers.

- `variable`: Character string indicating the data type:

  - The year (e.g., `"2023"`) for specific year data.

  - The quantile label (e.g., `"q50_1981_to_2010"`,
    `"q25_1981_to_2010"`) for aggregate data.

- `pole`: Character string, either `"north"` or `"south"`.

- `smoothing_window`: Numeric, the window size used (`1` indicates raw
  data).

## Examples

``` r
if (FALSE) { # \dontrun{
# Get Arctic data for 2022 and 2023 with default 5-day smoothing
ice_data_arctic_smooth = fetch_sea_ice_extent(years = c(2022, 2023))
print(head(ice_data_arctic_smooth))

# Get Arctic data for 2022 and 2023 with NO smoothing (raw data)
ice_data_arctic_raw = fetch_sea_ice_extent(years = c(2022, 2023), window = 1)
print(head(ice_data_arctic_raw))

# Example of plotting (requires ggplot2, dplyr, lubridate)
if (requireNamespace("ggplot2", quietly = TRUE) &&
    requireNamespace("dplyr", quietly = TRUE) &&
    requireNamespace("lubridate", quietly = TRUE)) {

  library(ggplot2)
  library(dplyr)
  library(lubridate)

  # Plot 2023 Arctic raw data against historical raw range/median
  fetch_sea_ice_extent(years = 2023, pole = "north", window = 1) %>%
    filter(variable %in% c("2023", "q0_1981_to_2010", "q100_1981_to_2010", "q50_1981_to_2010")) %>%
    # Add a temporary DOY column for plotting alignment
    mutate(doy = yday(date)) %>%
    ggplot(aes(x = doy, y = ice_extent_mi_sqkm, color = variable)) +
    geom_line(linewidth = 1) +
    labs(title = "Arctic Sea Ice Extent (2023 Raw vs 1981-2010 Raw)",
         x = "Day of Year",
         y = "Ice Extent (Million sq km)",
         color = "Data Series") +
    theme_minimal()
}
} # }
```
