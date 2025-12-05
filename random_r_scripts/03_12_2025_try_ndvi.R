library(tidyverse)
library(here)
library(glue)
library(sf)
library(jsonlite)
devtools::load_all()

# ++++++++++++++++++++++++++++++
# download ----
# ++++++++++++++++++++++++++++++
geo_hh <- giscoR::gisco_get_nuts(country = "DE") %>% filter(NUTS_NAME == "HAMBURG")


# ++++++++++++++++++++++++++++++
# download most recent ndvi for hamburg ----
# ++++++++++++++++++++++++++++++
d_keys <- cdse_set_credentials()
cdse_download_ndvi(date_start = Sys.Date(), clipsrc = geo_hh, output_dir = "~/LIXO/", access_key = d_keys$access_key, secret_key = d_keys$secret_key)
