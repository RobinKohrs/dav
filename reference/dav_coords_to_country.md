# Get Country from Coordinates (Spatial)

This function accepts latitude and longitude coordinates and returns the
country name using a spatial join with data from the `rnaturalearth`
package. It is vectorized and efficient for data frames.

## Usage

``` r
dav_coords_to_country(lat, lon)
```

## Arguments

- lat:

  Numeric vector. Latitude.

- lon:

  Numeric vector. Longitude.

## Value

A character vector containing the country names. NA where not found or
coordinates are invalid.

## Examples

``` r
if (FALSE) { # \dontrun{
# Scalar usage
dav_coords_to_country(47.2, 11.4)

# Vectorized usage in dplyr
library(dplyr)
df <- data.frame(lat = c(47.2, 48.8), lon = c(11.4, 2.3))
df %>% mutate(country = dav_coords_to_country(lat, lon))
} # }
```
