## Prepare bundled poles-of-inaccessibility for Vienna Zählbezirke
## Source: computed from Statistik Austria Zählbezirk polygons (EPSG:3857)

library(sf)

wien_income_poi <- sf::st_read(
    here::here("data-raw", "wien_income_poi.geojson"),
    quiet = TRUE
)

usethis::use_data(wien_income_poi, overwrite = TRUE)
