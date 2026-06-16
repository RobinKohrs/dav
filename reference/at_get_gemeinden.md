# Get Austrian Gemeinde Geodaten for Any Year

Downloads and returns Austrian gemeinde (municipality) geodaten for any
year from 2011 to 2025. The data is downloaded on-demand and returned as
an sf object.

## Usage

``` r
at_get_gemeinden(year, cache = TRUE)
```

## Arguments

- year:

  Integer. The year for which to download gemeinde data (2011-2025).

- cache:

  Logical. If TRUE (default), caches the downloaded data in a temporary
  directory to avoid re-downloading the same year multiple times in the
  same session.

## Value

An sf object containing gemeinde geodaten for the specified year

## Examples

``` r
# Get gemeinde data for 2025
gemeinden_2025 = at_get_gemeinden(2025)
#> Downloading gemeinde data for year: 2025 
#> Warning: URL 'https://www.statistik.gv.at/gs-open/GEODATA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=GEODATA:STATISTIK_AUSTRIA_GEM_20250101&outputFormat=SHAPE-ZIP&format_options=CHARSET:UTF-8': Timeout of 60 seconds was reached
#> Error in value[[3L]](cond): Failed to download gemeinde data for year 2025: cannot open URL 'https://www.statistik.gv.at/gs-open/GEODATA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=GEODATA:STATISTIK_AUSTRIA_GEM_20250101&outputFormat=SHAPE-ZIP&format_options=CHARSET:UTF-8'

# Get gemeinde data for 2020
gemeinden_2020 = at_get_gemeinden(2020)
#> Downloading gemeinde data for year: 2020 
#> Warning: URL 'https://www.statistik.gv.at/gs-open/GEODATA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=GEODATA:STATISTIK_AUSTRIA_GEM_20200101&outputFormat=SHAPE-ZIP&format_options=CHARSET:UTF-8': Timeout of 60 seconds was reached
#> Error in value[[3L]](cond): Failed to download gemeinde data for year 2020: cannot open URL 'https://www.statistik.gv.at/gs-open/GEODATA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=GEODATA:STATISTIK_AUSTRIA_GEM_20200101&outputFormat=SHAPE-ZIP&format_options=CHARSET:UTF-8'

# Plot the gemeinden
plot(gemeinden_2025$geometry)
#> Error: object 'gemeinden_2025' not found
```
