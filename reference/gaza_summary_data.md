# Fetches summary data across all datasets

This includes the latest cumulative values for casualties in Gaza and
the West Bank, and demographic composition for the 'Killed in Gaza' name
list. This function is useful for getting a quick overview and for
dynamically finding the page count for the `gaza_killed_in_gaza`
function.

## Usage

``` r
gaza_summary_data()
```

## Value

A list containing the summary data with sections for gaza, west_bank,
known_killed_in_gaza, and known_press_killed_in_gaza

## Details

The summary data provides:

- **Gaza section**: Latest cumulative values from daily reports
  including total killed, children killed, women killed, medical
  personnel killed, journalists killed, injured totals, and
  famine-related deaths

- **West Bank section**: Latest cumulative values including total
  killed, children killed, injured totals, and settler attacks

- **Known killed in Gaza**: Demographic breakdown by gender and age
  groups from the names list

- **Known press killed in Gaza**: Count of journalists in the names list

## Examples

``` r
# Get latest summary statistics
summary_info = gaza_summary_data()
#> Fetching summary data from: https://data.techforpalestine.org/api/v3/summary.min.json
#> Error in gaza_summary_data(): Failed to fetch summary data. Status code: 429
print(summary_info$gaza$killed$total)
#> Error: object 'summary_info' not found
print(summary_info$known_killed_in_gaza$pages)
#> Error: object 'summary_info' not found

# Get latest Gaza statistics
gaza_stats = summary_info$gaza
#> Error: object 'summary_info' not found
cat("Total killed in Gaza:", gaza_stats$killed$total, "\n")
#> Error: object 'gaza_stats' not found
cat("Children killed:", gaza_stats$killed$children, "\n")
#> Error: object 'gaza_stats' not found
cat("Women killed:", gaza_stats$killed$women, "\n")
#> Error: object 'gaza_stats' not found
```
