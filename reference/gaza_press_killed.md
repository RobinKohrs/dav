# Fetches the list of journalists killed in Gaza

Fetches the list of journalists killed in Gaza

## Usage

``` r
gaza_press_killed(format = "df", minified = TRUE)
```

## Arguments

- format:

  A string specifying the return format. Either "df" (default) to get a
  data frame from the CSV endpoint or "json" for the raw JSON data.

- minified:

  Logical. Whether to return minified JSON. Default is TRUE.

## Value

A data frame or a list containing the data.

## Details

**Data Source:** The file is updated when a new list is released by
Gaza's Government Media Office or when incremental updates about new
individual incidents are received. These are sourced from the Ministry's
Telegram Channel.

The ministry has previously released photos of some of those killed,
which can be retrieved in Arabic and English from their public Google
Drive. As of writing, it includes photos for just over half of the list.

**Data Fields:** Each record contains:

- `name`: Original Arabic name from the source list

- `name_en`: English name translation

- `notes`: Includes agency they worked for & available detail on how
  they were killed

## Examples

``` r
# Get as data frame (recommended)
press_df = gaza_press_killed()
#> Fetching press killed data from: https://data.techforpalestine.org/api/v2/press_killed_in_gaza.csv
#> Warning: Failed to open 'https://data.techforpalestine.org/api/v2/press_killed_in_gaza.csv': The requested URL returned error: 429
#> Error: cannot open the connection

# Get as JSON
press_json = gaza_press_killed(format = "json")
#> Fetching press killed data from: https://data.techforpalestine.org/api/v2/press_killed_in_gaza.min.json
#> Error in gaza_press_killed(format = "json"): Failed to fetch press killed data. Status code: 429

# Get unminified JSON
press_full = gaza_press_killed(format = "json", minified = FALSE)
#> Fetching press killed data from: https://data.techforpalestine.org/api/v2/press_killed_in_gaza.json
#> Error in gaza_press_killed(format = "json", minified = FALSE): Failed to fetch press killed data. Status code: 429
```
