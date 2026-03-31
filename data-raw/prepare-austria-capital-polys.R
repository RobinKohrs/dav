library(tidyverse)
library(here)
library(glue)
library(sf)
library(rajudas)
library(jsonlite)

# -------------------------------------------------------------------------
# Read Gemeinden
# -------------------------------------------------------------------------
read_sf("/Users/rk/Library/Mobile Documents/com~apple~CloudDocs/geodata/österreich/landeshauptstädte/at_landeshauptstaedte.gpkg") -> at_capitals_polys
# Save
usethis::use_data(at_capitals_polys, overwrite = TRUE)
