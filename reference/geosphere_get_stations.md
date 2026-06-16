# Download Geosphere Austria Station Metadata

Retrieves station metadata from the Geosphere Austria API, typically
from a dataset's metadata endpoint. Optionally caches the result to a
local file.

## Usage

``` r
geosphere_get_stations(
  metadata_url =
    "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v2-1d/metadata",
  output_path = NULL,
  return_format = c("sf", "dataframe"),
  cache_format = c("rds", "csv"),
  crs = 4326,
  verbose = FALSE
)
```

## Arguments

- metadata_url:

  The full URL to the metadata endpoint of a specific Geosphere API
  dataset that contains station information (e.g., ".../metadata").
  Defaults to the metadata URL for the "klima-v2-1d" dataset.

- output_path:

  Optional. A file path (e.g., "stations.rds" or "stations.csv") where
  the downloaded and processed station data (as an `sf` object or data
  frame) should be saved for caching. If the file exists, it will be
  loaded from the cache instead of downloading. Using ".rds" is
  recommended for saving the `sf` object perfectly.

- return_format:

  Character. Either `"sf"` (default) to return an `sf` spatial data
  frame or `"dataframe"` to return a regular data frame.

- cache_format:

  Character. Format to use for caching if `output_path` is provided.
  Either `"rds"` (default, recommended for `sf` objects) or `"csv"`.
  Ignored if `output_path` is `NULL`. Note that saving `sf` objects to
  CSV loses spatial information unless WKT geometry is explicitly
  handled.

- crs:

  Coordinate reference system for the output `sf` object. Defaults to
  `4326` (WGS 84), assuming the API provides standard
  longitude/latitude.

- verbose:

  Logical. If `TRUE`, print informative messages.

## Value

An `sf` spatial data frame (if `return_format = "sf"`) or a regular data
frame (if `return_format = "dataframe"`) containing station metadata.
Returns `NULL` if downloading or processing fails and no cache exists.

## Examples

``` r
if (FALSE) { # \dontrun{
# Ensure sf is installed: install.packages("sf")

# Example 1: Get stations as an sf object (default)
stations_sf <- geosphere_get_stations(verbose = TRUE)
if (!is.null(stations_sf)) {
  print(head(stations_sf))
  plot(st_geometry(stations_sf))
}

# Example 2: Get stations as a data frame and cache to RDS
stations_df <- geosphere_get_stations(
  return_format = "dataframe",
  output_path = "geosphere_stations_cache.rds",
  cache_format = "rds",
  verbose = TRUE
)
# Next time, it will load from "geosphere_stations_cache.rds" if it exists
stations_cached <- geosphere_get_stations(output_path = "geosphere_stations_cache.rds")

# Example 3: Use a different metadata URL (replace with a valid one)
# custom_url <- "https://dataset.api.hub.geosphere.at/v1/..."
# custom_stations <- geosphere_get_stations(metadata_url = custom_url)

} # }
```
