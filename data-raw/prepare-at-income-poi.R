## Prepare bundled poles of inaccessibility / centroids for Austria-wide Zählsprengel
## Source: Statistik Austria ZSP polygon boundaries (EPSG:31287 MGI / Austria Lambert)

library(sf)

at_income_poi <- sf::st_read(
    here::here("data-raw", "at_income_poi.geojson"),
    quiet = TRUE
) |>
    # GeoJSON carries no CRS declaration — coordinates are MGI / Austria Lambert
    sf::st_set_crs(31287) |>
    # Rename g_id to ZGEB so it matches the expected column in statistik_get_zsp_einkommen()
    dplyr::rename(ZGEB = g_id) |>
    # Reproject to EPSG:3857 (Pseudo-Mercator) matching the WMS service and wien_income_poi
    sf::st_transform(3857)

usethis::use_data(at_income_poi, overwrite = TRUE)
