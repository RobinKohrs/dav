library(tidyverse)
library(here)
library(glue)
library(sf)
library(rajudas)
library(jsonlite)

# -------------------------------------------------------------------------
# Read Gemeinden
# -------------------------------------------------------------------------
url = "https://data.statistik.gv.at/data/OGDEXT_GEM_1_STATISTIK_AUSTRIA_20250101.zip"
temp_zip = tempfile(fileext = ".zip")
temp_dir = tempdir()

download.file(url, destfile = temp_zip, mode = "wb")
unzipped_files = unzip(temp_zip, exdir = temp_dir)
shp_file = unzipped_files[grepl("\\.shp$", unzipped_files, ignore.case = TRUE)][1]

geo_data = st_read(shp_file)

# Define GKZ codes for state capitals (including districts of Vienna)
gkz_capitals = c(
  # Vienna districts (23 of them)
  seq(90101,92301, by=100),

  # Other Landeshauptstädte
  30201, 10101, 40101, 50101, 70101, 80207, 60101, 20101
)

# Filter for those GKZs
capitals_raw = geo_data %>%
  filter(g_id %in% gkz_capitals)

# Dissolve Vienna's districts into one geometry
vienna_dissolved = capitals_raw %>%
  filter(str_starts(g_id, "9")) %>%
  st_union() %>%
  st_sf(g_id = "90000", g_name = "Wien") %>%
  rename(geometry=3)

# Filter out Vienna's districts from main data and bind the dissolved version
other_capitals = capitals_raw %>%
  filter(!str_starts(g_id, "9"))

# Combine everything into one sf object
at_capitals_polys = bind_rows(other_capitals, vienna_dissolved)

# Optional: sort by name or GKZ
at_capitals_polys = at_capitals_polys %>% arrange(g_name)

# Save
usethis::use_data(at_capitals_polys, overwrite = TRUE)
