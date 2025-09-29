# data-raw/prepare_austria_shapes.R

# --- Dependencies ---
# Need to install these if you don't have them
# install.packages("giscoR")
# install.packages("sf")
# install.packages("dplyr") # Useful for selecting/renaming
# install.packages("usethis")

library(giscoR)
library(sf)
library(dplyr)
library(usethis)

# --- Configuration ---
# Define the resolutions you want to include
# Check giscoR documentation for available codes (e.g., 60M, 20M, 10M, 03M, 01M)
target_resolutions = c("60", "10", "01") # Low, Medium, High example

# --- Data Fetching and Processing ---
austria_shapes_list = list()

for (res in target_resolutions) {
  cat("Fetching Austria shape for resolution:", res, "\n")
  tryCatch({
    shape = giscoR::gisco_get_countries(
      resolution = res,
      country = "AT", # ISO2 code for Austria
      epsg = "4326" # Ensure consistent WGS84 CRS
    )

    # Select and rename columns for consistency (optional but good practice)
    shape_processed = shape %>%
      select(
        name = CNTR_NAME, # Or other relevant name column
        name_en = NAME_ENGL,
        iso3_code = ISO3_CODE,
        geometry
      )

    # Store in the list with resolution as the name
    austria_shapes_list[[res]] = shape_processed

  }, error = function(e) {
    warning("Failed to download/process resolution ", res, ": ", e$message)
  })
  # Add a small delay to be polite to the server (optional)
  Sys.sleep(1)
}

# --- Save the Data Object ---
# Check if we actually got any data
if (length(austria_shapes_list) > 0) {
  # Save the *list* containing all shapes as a single .rda file in data/
  # Naming the list object clearly is good practice
  austria_shapes = austria_shapes_list
  usethis::use_data(austria_shapes, overwrite = TRUE)
  cat("Successfully saved austria_shapes object to data/austria_shapes.rda\n")
} else {
  stop("Failed to retrieve any shape data. Aborting.")
}

# --- Clean up ---
rm(target_resolutions, res, shape, shape_processed, austria_shapes_list, austria_shapes)
