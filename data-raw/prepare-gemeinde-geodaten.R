# data-raw/prepare-gemeinde-geodaten.R

# --- Dependencies ---
# Need to install these if you don't have them
# install.packages("sf")
# install.packages("dplyr")
# install.packages("usethis")
# install.packages("glue")

library(sf)
library(dplyr)
library(usethis)
library(glue)

# --- Configuration ---
# Download only the most recent gemeinde geodaten (2025)
year = 2025
url = glue(
    "https://data.statistik.gv.at/data/OGDEXT_GEM_1_STATISTIK_AUSTRIA_{year}0101.zip"
)

# --- Download Most Recent Data ---
cat("Downloading most recent gemeinde geodaten for year:", year, "\n")

# Create temporary files
temp_zip = tempfile(fileext = ".zip")
temp_dir = tempdir()

# Download and extract
tryCatch(
    {
        download.file(url, destfile = temp_zip, mode = "wb")
        unzipped_files = unzip(temp_zip, exdir = temp_dir)

        # Find the shapefile
        shp_file = unzipped_files[grepl(
            "\\.shp$",
            unzipped_files,
            ignore.case = TRUE
        )][1]

        if (is.na(shp_file)) {
            stop("No shapefile found for year ", year)
        }

        # Read the shapefile
        geo_data = st_read(shp_file, quiet = TRUE)

        # Add year column for identification
        geo_data$year = year

        # Process the data for inclusion in the package
        gemeinde_geodaten = geo_data %>%
            # Select relevant columns (adjust based on actual column names)
            select(
                g_id, # Gemeinde ID
                g_name, # Gemeinde name
                geometry, # Geometry
                year # Year
            ) %>%
            # Sort by name for consistency
            arrange(g_name)

        # Save the most recent gemeinde data for direct use in the package
        usethis::use_data(gemeinde_geodaten, overwrite = TRUE)
        cat(
            "Successfully saved gemeinde_geodaten object to data/gemeinde_geodaten.rda\n"
        )

        # Summary
        cat("\n=== Download Summary ===\n")
        cat("Successfully downloaded gemeinde data for year:", year, "\n")
        cat("Total number of gemeinden:", nrow(gemeinde_geodaten), "\n")
        cat("Data saved as 'gemeinde_geodaten' for package use\n")
        cat(
            "Use at_get_gemeinden(year) function to download other years on-demand\n"
        )

        # Clean up temporary files
        unlink(temp_zip)
        unlink(unzipped_files)
    },
    error = function(e) {
        # Clean up on error
        unlink(temp_zip)
        stop(
            "Failed to download gemeinde data for year ",
            year,
            ": ",
            e$message
        )
    }
)

# --- Clean up ---
rm(
    year,
    url,
    temp_zip,
    temp_dir,
    unzipped_files,
    shp_file,
    geo_data,
    gemeinde_geodaten
)
