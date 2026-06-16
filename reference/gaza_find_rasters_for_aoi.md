# Find Rasters Intersecting an AOI (Polygon or Points)

This function identifies raster files from a tile index that intersect
with a given Area of Interest (AOI), which can be a polygon or a set of
points. It returns a character vector of the full paths to the
qualifying raster files.

## Usage

``` r
gaza_find_rasters_for_aoi(aoi_path, tile_index_path, overlap_threshold = 0.5)
```

## Arguments

- aoi_path:

  A character string. The full path to the spatial file (e.g.,
  GeoPackage, Shapefile) defining your Area of Interest.

- tile_index_path:

  A character string. The full path to the master vector file (e.g.,
  GeoPackage, Shapefile) containing the footprints of all rasters.

- overlap_threshold:

  A numeric value between 0 and 1. If the AOI is a polygon, this
  specifies the minimum required overlap as a proportion of the AOI's
  total area. Defaults to 0.5. Ignored for point AOIs.

## Value

A character vector of full paths to the raster files that meet the
intersection criteria. Returns an empty character vector if no rasters
are found.
