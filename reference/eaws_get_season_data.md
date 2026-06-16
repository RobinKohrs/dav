# Get EAWS Avalanche Fatality Data for a Season

Fetches avalanche fatality data from avalanches.org for a specific
season. Handles different data formats for seasons before and after
2017.

## Usage

``` r
eaws_get_season_data(season)
```

## Arguments

- season:

  Integer or character. The starting year of the season (e.g., 2020 for
  the 2020-2021 season).

## Value

A data frame containing the avalanche fatality data. Structure varies
slightly between pre- and post-2017 data.

## Examples

``` r
if (FALSE) { # \dontrun{
# Get data for 2020 (modern format)
data_2020 <- eaws_get_season_data(2020)

# Get data for 2009 (aggregated format)
data_2009 <- eaws_get_season_data(2009)
} # }
```
