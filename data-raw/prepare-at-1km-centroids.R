## Prepare at_1km_centroids dataset
##
## Reads raw centroids (WGS84 lon/lat) for every populated 1km INSPIRE grid
## cell in Austria and adds the standard INSPIRE cell identifier derived from
## EPSG:3035 (ETRS89-LAEA) coordinates.
##
## Source: at_1km_centroids.csv (x = lon, y = lat, EPSG:4326)

library(sf)
library(readr)

raw <- readr::read_csv("data-raw/at_1km_centroids.csv")

# Create sf in WGS84
pts_4326 <- sf::st_as_sf(raw, coords = c("x", "y"), crs = 4326)

# Transform to LAEA (EPSG:3035) to derive standard INSPIRE 1km cell IDs
pts_3035  <- sf::st_transform(pts_4326, 3035)
coords_3035 <- sf::st_coordinates(pts_3035)

# INSPIRE 1km grid cell identifier: 1kmN{northing_km}E{easting_km}
cell_id <- paste0(
  "1kmN", floor(coords_3035[, "Y"] / 1000),
  "E",   floor(coords_3035[, "X"] / 1000)
)

at_1km_centroids        <- pts_4326
at_1km_centroids$cell_id <- cell_id

usethis::use_data(at_1km_centroids, overwrite = TRUE)
