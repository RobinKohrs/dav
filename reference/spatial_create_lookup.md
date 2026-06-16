# Create a two-level spatial lookup from a geospatial raster

This function processes a geospatial raster file (e.g., GeoTIFF or
NetCDF) to generate a two-level lookup structure suitable for web
applications. It partitions the raster cells into a specified number of
spatially coherent groups using k-means clustering and exports the data
as a series of CSV files.

The output consists of:

1.  A main index file (`main.csv`) containing the overall bounding box
    for each group.

2.  A directory of individual group files (`g_*.csv`), where each file
    contains the detailed coordinates and bounding box for every cell
    within that group.

## Usage

``` r
spatial_create_lookup(
  input_raster_file,
  output_base_dir,
  n_groups = 500,
  crs_output = "EPSG:4326",
  seed = 123,
  resampling_method = "bilinear"
)
```

## Arguments

- input_raster_file:

  A string path to the input raster file. Must be a format readable by
  [`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).

- output_base_dir:

  A string path to the directory where the output `lookups` folder will
  be created.

- n_groups:

  The target number of groups (clusters) to partition the raster cells
  into. This determines the number of rows in `main.csv`.

- crs_output:

  The target Coordinate Reference System (CRS) for the output data,
  specified as an EPSG string (e.g., "EPSG:4326"). Defaults to WGS 84,
  the standard for web maps.

- seed:

  An integer to set the random seed for k-means clustering, ensuring
  reproducible results. Defaults to 123.

- resampling_method:

  The resampling method for reprojection. Defaults to "bilinear". Use
  "near" for categorical data. See
  [`terra::project`](https://rspatial.github.io/terra/reference/project.html).

## Value

Invisibly returns a list containing the paths to the generated
`main.csv` file, the directory of group CSVs, the path to the grid
vector file, and the path to the reprojected raster file.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a dummy raster file for the example
r = terra::rast(xmin = 9, xmax = 17, ymin = 46, ymax = 49,
                 resolution = 0.01, crs = "EPSG:4326")
r[] = 1:terra::ncell(r)
temp_raster_path = file.path(tempdir(), "austria_dummy.tif")
terra::writeRaster(r, temp_raster_path)

# Define an output directory
temp_output_dir = file.path(tempdir(), "my_app_data")

# Run the function
create_spatial_lookup(
  input_raster_file = temp_raster_path,
  output_base_dir = temp_output_dir,
  n_groups = 50
)

# Check the output
list.files(file.path(temp_output_dir, "lookups"))
list.files(file.path(temp_output_dir, "lookups", "grid_cells"))
} # }
```
