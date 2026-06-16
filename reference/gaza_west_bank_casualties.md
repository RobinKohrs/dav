# Fetches the daily casualty reports for the West Bank

This dataset provides a time series of killed and injured counts since
October 7th, 2023.

## Usage

``` r
gaza_west_bank_casualties(format = "df", minified = TRUE)
```

## Arguments

- format:

  A string specifying the return format. Either "df" (default) to get a
  data frame from the CSV endpoint or "json" for the raw JSON data.

- minified:

  Logical. Whether to return minified JSON. Default is TRUE.

## Value

A data frame or a list containing the daily casualty data for the West
Bank.

## Details

**Data Source:** For West Bank data, the dataset depends on UN OCHA.

There are two types of source material they provide that are used to
build the time series:

- **verified**: These are the ones independently verified by UN OCHA
  personnel and provided via their casualty database.

- **flash-updates**: These are incidents reported to the UN, but not yet
  verified and they are the source of those root level values in the
  report object.

Verified values will lag the ones that come from Flash Updates, so the
field will be missing (optional) on more recent report dates, but
generally continuous going back through older report dates once
populated values are encountered.

Flash Updates occasionally miss days and as of March 25 are only
available for the West Bank on a weekly basis.

**Data Fields:** Each daily report contains fields for:

- `report_date`: Date in YYYY-MM-DD format

- `verified.killed`: Killed persons on the given report date (verified)

- `verified.killed_cum`: Cumulative number of confirmed killed persons
  (verified)

- `verified.injured`: Injured persons on the given report date
  (verified)

- `verified.injured_cum`: Cumulative number of injured persons
  (verified)

- `verified.killed_children`: Number of children killed on the given
  report date (verified)

- `verified.killed_children_cum`: Cumulative number of children killed
  (verified)

- `verified.injured_children`: Number of children injured on the given
  report date (verified)

- `verified.injured_children_cum`: Cumulative number of children injured
  (verified)

- `killed_cum`: Same as verified.killed_cum but yet to be independently
  verified

- `killed_children_cum`: Same as verified.killed_children_cum but yet to
  be independently verified

- `injured_cum`: Same as verified.injured_cum but yet to be
  independently verified

- `injured_children_cum`: Same as verified.injured_children_cum but yet
  to be independently verified

- `settler_attacks_cum`: Cumulative number of attacks by settlers on
  civilians

- `flash_source`: Either "un" or "fill" (see March 25 update for more
  detail)

## Examples

``` r
# Get as data frame (recommended)
west_bank_df = gaza_west_bank_casualties()
#> Fetching West Bank daily casualties data from: https://data.techforpalestine.org/api/v2/west_bank_daily.csv
#> Warning: Failed to open 'https://data.techforpalestine.org/api/v2/west_bank_daily.csv': The requested URL returned error: 429
#> Error: cannot open the connection

# Get as JSON
west_bank_json = gaza_west_bank_casualties(format = "json")
#> Fetching West Bank daily casualties data from: https://data.techforpalestine.org/api/v2/west_bank_daily.min.json
#> Error in gaza_west_bank_casualties(format = "json"): Failed to fetch West Bank daily casualties data. Status code: 429

# Get unminified JSON
west_bank_full = gaza_west_bank_casualties(format = "json", minified = FALSE)
#> Fetching West Bank daily casualties data from: https://data.techforpalestine.org/api/v2/west_bank_daily.json
#> Error in gaza_west_bank_casualties(format = "json", minified = FALSE): Failed to fetch West Bank daily casualties data. Status code: 429
```
