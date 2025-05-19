library(tidyverse)
library(here)
library(glue)
library(sf)
library(davR)
library(jsonlite)

# get stations  ------------------------------------------------------
stations = davR::geosphere_get_stations()

stations_ids_to_filter = c(
  5925,
  105,
  30,
  56,
  131,
  48,
  7704,
  11803,
  15,
  93
  )


geosphere_stations_in_capitals = stations %>%
  filter(
    id %in% stations_ids_to_filter
  )

usethis::use_data(geosphere_stations_in_capitals)
