# Fetches and processes the v3 list of known individuals killed in Gaza

This function retrieves the dataset of names of those killed in Gaza
from the v3 API endpoint. It then processes the data to create a
time-series of cumulative deaths based on the release dates.

## Usage

``` r
gaza_killed_v3()
```

## Value

A data frame with daily cumulative deaths, children deaths, and press
deaths.
