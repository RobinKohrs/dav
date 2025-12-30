# Load required packages
library(here)
library(tidyverse)
library(sf)
library(glue)
library(httr)
library(cli)
library(davR)
library(terra)


# Set up project paths
p_data = here("data")
p_csv = here("data", "csv")
p_excel = here("data", "excel")
p_geo_vec = here("data", "geodata", "vector")
p_geo_ras = here("data", "geodata", "raster")
p_graphic = here("graphic_output")

