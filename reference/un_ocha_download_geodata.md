# Download Geodata from UN OCHA

Downloads geodata layers from the UN OCHA ArcGIS FeatureServer based on
keywords. Handles large layers by chunking requests using object IDs.

## Usage

``` r
un_ocha_download_geodata(
  keywords = c("Obstacle", "Barrier", "Checkpoint", "Road", "Palestine", "Gaza",
    "West Bank", "Crossing", "Fence", "Gate"),
  output_dir = "downloads_geodata",
  large_layer_threshold = 1e+05,
  download_large = FALSE,
  crs = "4326"
)
```

## Arguments

- keywords:

  Character vector. Keywords to filter services/layers
  (case-insensitive).

- output_dir:

  Character. Directory to save downloaded GeoJSON files.

- large_layer_threshold:

  Integer. Threshold for number of features to consider a layer "large".
  If a layer exceeds this, the user is prompted (if interactive) or it
  follows `download_large`.

- download_large:

  Logical. If `TRUE`, automatically downloads large layers without
  prompting. If `FALSE` (default), asks in interactive mode or skips in
  non-interactive mode.

- crs:

  Character or Integer. CRS for output coordinates (default "4326").

## Value

Invisible list of file paths to downloaded files.
