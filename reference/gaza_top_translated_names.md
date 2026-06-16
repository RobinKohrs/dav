# Fetches the counts of the top 10 translated first names by age group

Fetches the counts of the top 10 translated first names by age group

## Usage

``` r
gaza_top_translated_names()
```

## Value

A list containing the name frequency data, categorized by age group.

## Details

This dataset is used to derive estimates of children killed for the home
page name cards as documented on the Summary dataset page.

## Examples

``` r
# Get top translated names by age group
top_names = gaza_top_translated_names()
#> Fetching top translated names data from: https://data.techforpalestine.org/api/v2/killed-in-gaza/name-freq-en.json
#> Error in gaza_top_translated_names(): Failed to fetch top translated names data. Status code: 429
print(top_names$lists$girl)
#> Error: object 'top_names' not found
print(top_names$lists$boy)
#> Error: object 'top_names' not found
print(top_names$lists$woman)
#> Error: object 'top_names' not found
print(top_names$lists$man)
#> Error: object 'top_names' not found

# Get child counts
print(top_names$totalPeople$boy)   # Total boys: 10656
#> Error: object 'top_names' not found
print(top_names$totalPeople$girl)   # Total girls: 7801
#> Error: object 'top_names' not found
```
