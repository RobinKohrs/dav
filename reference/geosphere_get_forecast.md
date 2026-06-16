# Get Weather Forecast Data from GeoSphere Austria

Downloads the latest forecast data (NWP, Nowcast, or Ensemble) and
either returns the full raster dataset or extracts a time series for a
specific point. Optionally saves the processed result to disk.

## Usage

``` r
geosphere_get_forecast(
  host,
  x = NULL,
  y = NULL,
  level = NULL,
  subdatasets = NULL,
  download_dir = NULL,
  timezone = "Europe/Paris"
)
```

## Arguments

- host:

  Character. The data source: `"nwp"`, `"nowcast"`, or `"ensemble"`.

- x:

  Numeric. Optional. Longitude coordinate (in WGS84, decimal degrees)
  for point data extraction. If `NULL` (default) or invalid, the full
  raster is returned.

- y:

  Numeric. Optional. Latitude coordinate (in WGS84, decimal degrees) for
  point data extraction. If `NULL` (default) or invalid, the full raster
  is returned.

- level:

  Optional. The vertical level to filter for (e.g., 850 hPa). Filtering
  depends on layer naming conventions in the source file.

- subdatasets:

  Optional. Character vector of subdatasets (variables) to load (e.g.,
  `"T"`, `"U"`, `"V"`). If `NULL` (default),
  [`terra::rast`](https://rspatial.github.io/terra/reference/rast.html)
  attempts to load the first/default subdataset(s).

- download_dir:

  Character or NULL. Optional. Path to a directory for storing
  downloaded *source* files (allows caching) and saving the *processed
  results*. If `NULL` (default), source files are downloaded to a
  temporary location (and removed at session end) and results are not
  saved to disk. If a path is provided, the processed result (raster or
  point data) will be saved there using a timestamped name (e.g.,
  `YYYYMMDD_HHMMSS_<host>_raster.nc` or
  `YYYYMMDD_HHMMSS_<host>_point.csv`).

- timezone:

  Character. The target timezone for the time information (e.g.,
  `"Europe/Vienna"`, `"UTC"`). Defaults to `"Europe/Paris"`.

## Value

If valid `x` and `y` coordinates within the approximate Austrian
bounding box are provided, returns a `data.frame` with columns `value`
and `time`. Otherwise, returns a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
object containing the requested forecast data layers. In both cases, if
`download_dir` was specified, the returned object will also be saved to
that directory.

## Examples

``` r
if (FALSE) { # \dontrun{
# --- Examples ---

# Example 1: Get point data for Vienna, use temp download, return df
vienna_lon = 16.3738
vienna_lat = 48.2082
nwp_vienna_point_mem = geosphere_get_forecast(host = "nwp",
                                              x = vienna_lon, y = vienna_lat,
                                              timezone = "Europe/Vienna",
                                              download_dir = NULL) # Explicitly NULL
if (inherits(nwp_vienna_point_mem, "data.frame")) {
  print(head(nwp_vienna_point_mem))
}

# Example 2: Get point data, specify dir, save CSV, return df
my_dir = "my_forecast_data"
nwp_vienna_point_disk = geosphere_get_forecast(host = "nwp",
                                               x = vienna_lon, y = vienna_lat,
                                               timezone = "Europe/Vienna",
                                               download_dir = my_dir)
# Check if the CSV file exists in my_dir
list.files(my_dir, pattern = "\\.csv$")

# Example 3: Get full raster, specify dir, save NetCDF, return SpatRaster
ensemble_t850_raster_disk = geosphere_get_forecast(host = "ensemble",
                                                   x = NULL, y = NULL,
                                                   subdatasets = "T",
                                                   level = 850,
                                                   timezone = "UTC",
                                                   download_dir = my_dir)
# Check if the NetCDF file exists in my_dir
list.files(my_dir, pattern = "\\.nc$")
if (inherits(ensemble_t850_raster_disk, "SpatRaster")) {
  print(ensemble_t850_raster_disk)
}

# Example 4: Get full raster, use temp download, return SpatRaster
nowcast_raster_mem = geosphere_get_forecast(host = "nowcast", download_dir = NULL)
if (inherits(nowcast_raster_mem, "SpatRaster")) {
   print(nowcast_raster_mem)
}

} # }
```
