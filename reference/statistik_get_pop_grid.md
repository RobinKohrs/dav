# Download Population Counts for the Statistik Austria INSPIRE Grid

Downloads the 1km or 250m INSPIRE LAEA grid shapefile from Statistik
Austria, extracts cell centroids, and queries the WMS `GetFeatureInfo`
endpoint to obtain population counts (Hauptwohnsitz) per grid cell.

## Usage

``` r
statistik_get_pop_grid(
  year,
  resolution = c("1km", "250m"),
  sleep_ms = 10,
  cache_dir = "/Volumes/rr/geodata/oesterreich/population_grid",
  verbose = TRUE
)
```

## Arguments

- year:

  Integer. The reference year (e.g. 2025). Passed to the WMS as
  `YEAR:{year}-01-01`.

- resolution:

  Character. Grid resolution: `"1km"` (default) or `"250m"`.

- sleep_ms:

  Integer. Delay in milliseconds between requests (default: 10).

- cache_dir:

  Character. Directory used to store the downloaded grid shapefile and
  the intermediate WMS query results. A CSV file named
  `pop_1km_<year>.csv` or `pop_250m_<year>.csv` is written after each
  request, enabling resumable downloads. Defaults to
  `"/Volumes/rr/geodata/oesterreich/population_grid"`. Set to `NULL` to
  disable caching (grid and results are kept only in memory / tempdir).

- verbose:

  Logical. If `TRUE` (default), prints progress messages.

## Value

A data frame with columns `cell_id` (INSPIRE grid cell identifier) and
`hws` (integer, Hauptwohnsitz — persons with main residence in the
cell). Cells with no registered population are omitted.

## Examples

``` r
if (FALSE) { # \dontrun{
# 1km grid, Austria-wide
pop1km  <- statistik_get_pop_grid(2025)

# 250m grid (much larger — ~1.4 million cells)
pop250m <- statistik_get_pop_grid(2025, resolution = "250m")

# Join back to the grid polygons
grid   <- statistik_get_1km_grid()
result <- dplyr::left_join(grid, pop1km, by = "cell_id")
} # }
```
