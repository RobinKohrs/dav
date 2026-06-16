# Crop a List of Rasters to an AOI

This function takes a list of raster file paths, crops them to the
extent of a given Area of Interest (AOI), and saves the results to a
specified directory.

## Usage

``` r
gaza_crop_rasters_for_aoi(
  raster_list,
  aoi_path,
  output_dir,
  aoi_name = "cropped"
)
```

## Arguments

- raster_list:

  A character vector of full paths to the raster files that you want to
  crop.

- aoi_path:

  A character string. The full path to the spatial file (e.g.,
  GeoPackage, Shapefile) defining the cropping extent.

- output_dir:

  A character string. The path to the directory where the newly cropped
  rasters will be saved. The directory will be created if it does not
  exist.

- aoi_name:

  A character string used as a prefix for the cropped output files. For
  example, `aoi_name = "gaza_city"` results in
  `gaza_city_<raster_name>`.

## Value

Invisibly returns a character vector containing the full paths to the
newly created cropped raster files.
