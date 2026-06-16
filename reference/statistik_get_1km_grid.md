# Download the Statistik Austria 1km LAEA Grid

Downloads the official 1km INSPIRE LAEA grid polygon layer from
Statistik Austria's OGD portal, unzips it, reads it as an `sf` object,
and optionally joins population data.

## Usage

``` r
statistik_get_1km_grid(cache_dir = tempdir(), verbose = TRUE)
```

## Arguments

- cache_dir:

  Character. Directory where the zip and extracted shapefile are stored
  so repeated calls skip the download. Defaults to
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). Set to `NULL` to
  always re-download.

- verbose:

  Logical. If `TRUE` (default), prints progress messages.

## Value

An `sf` object with the 1km grid polygons in EPSG:3035 (LAEA Europe).
Contains at minimum a `cell_id` column (`GRD_ID` renamed) plus any
attributes bundled in the shapefile.

## Examples

``` r
if (FALSE) { # \dontrun{
grid <- statistik_get_1km_grid()

# Join with population data
pop  <- statistik_get_1km_pop(2025)
grid_pop <- dplyr::left_join(grid, pop, by = "cell_id")
} # }
```
