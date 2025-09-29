#' Get Austrian Gemeinde Geodaten for Any Year
#'
#' Downloads and returns Austrian gemeinde (municipality) geodaten for any year
#' from 2011 to 2025. The data is downloaded on-demand and returned as an sf object.
#'
#' @param year Integer. The year for which to download gemeinde data (2011-2025).
#' @param cache Logical. If TRUE (default), caches the downloaded data in a temporary
#'   directory to avoid re-downloading the same year multiple times in the same session.
#'
#' @return An sf object containing gemeinde geodaten for the specified year
#'
#' @examples
#' # Get gemeinde data for 2025
#' gemeinden_2025 = at_get_gemeinden(2025)
#'
#' # Get gemeinde data for 2020
#' gemeinden_2020 = at_get_gemeinden(2020)
#'
#' # Plot the gemeinden
#' plot(gemeinden_2025$geometry)
#'
#' @export
at_get_gemeinden <- function(year, cache = TRUE) {
    # Validate year input
    if (!is.numeric(year) || length(year) != 1) {
        stop("year must be a single numeric value")
    }

    if (year < 2011 || year > 2025) {
        stop("year must be between 2011 and 2025")
    }

    # Check if we have cached data for this year
    if (cache) {
        cache_key = paste0("gemeinden_", year)
        if (exists(cache_key, envir = .GlobalEnv)) {
            cat("Using cached data for year", year, "\n")
            return(get(cache_key, envir = .GlobalEnv))
        }
    }

    cat("Downloading gemeinde data for year:", year, "\n")

    # Construct URL for the specific year
    url = glue::glue(
        "https://data.statistik.gv.at/data/OGDEXT_GEM_1_STATISTIK_AUSTRIA_{year}0101.zip"
    )

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
            geo_data = sf::st_read(shp_file, quiet = TRUE)

            # Add year column for identification
            geo_data$year = year

            # Select and rename relevant columns
            geo_data = geo_data %>%
                dplyr::select(
                    g_id, # Gemeinde ID
                    g_name, # Gemeinde name
                    geometry, # Geometry
                    year # Year
                ) %>%
                # Sort by name for consistency
                dplyr::arrange(g_name)

            # Cache the data if requested
            if (cache) {
                assign(cache_key, geo_data, envir = .GlobalEnv)
            }

            # Clean up temporary files
            unlink(temp_zip)
            unlink(unzipped_files)

            cat("Successfully downloaded gemeinde data for year", year, "\n")
            cat("Number of gemeinden:", nrow(geo_data), "\n")

            return(geo_data)
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
}
