#' Find, Filter, and Crop Rasters by a Polygon AOI
#'
#' This function automates the process of selecting raster files that
#' significantly overlap with a given Area of Interest (AOI) polygon,
#' then crops and saves them. It uses namespace-qualified function calls
#' (e.g., terra::vect) for robustness and does not require packages to be loaded.
#'
#' @param aoi_path A character string. The full path to the polygon file
#'   (e.g., GeoPackage, Shapefile) defining your Area of Interest.
#' @param aoi_name the prefixed name for the cropped rasters. E.g "gaza_city" till turn
#' the rasters names into gaza_city_<raster_name>
#' @param tile_index_path A character string. The full path to the master
#'   GeoPackage or Shapefile that contains the footprints of all your rasters.
#' @param output_dir A character string. The path to the directory where the
#'   newly cropped rasters will be saved. The directory will be created if
#'   it does not exist.
#' @param overlap_threshold A numeric value between 0 and 1. The minimum
#'   required overlap as a proportion of the AOI's total area. For example,
#'   0.5 means the raster's footprint must cover at least 50% of the AOI.
#'   Defaults to 0.5.
#'
#' @return Invisibly returns a character vector containing the full paths to
#'   the newly created cropped raster files.
#' @export

gaza_get_planet_rasters_for_aoi <- function(
    aoi_path,
    aoi_name = "cropped",
    tile_index_path,
    output_dir,
    overlap_threshold = 0.5
) {
    # --- 1. Input Validation ---
    # Ensure the 'terra' package is installed
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop(
            "Package 'terra' is required but not installed. Please run: install.packages('terra')"
        )
    }

    stopifnot(
        "Error: aoi_path does not exist. Please check the file path." = file.exists(
            aoi_path
        ),
        "Error: tile_index_path does not exist. Please check the file path." = file.exists(
            tile_index_path
        ),
        "Error: overlap_threshold must be a number between 0 and 1." = is.numeric(
            overlap_threshold
        ) &&
            overlap_threshold >= 0 &&
            overlap_threshold <= 1
    )

    cat("--- Starting Raster Processing ---\n")

    # --- 2. Setup and Data Loading ---
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        cat("Created output directory at:", output_dir, "\n")
    }

    cat("Loading spatial data using 'terra'...\n")
    tile_index <- terra::vect(tile_index_path)
    aoi <- terra::vect(aoi_path)

    # Ensure CRS Consistency
    cat("Checking Coordinate Reference Systems (CRS)...\n")
    if (terra::crs(tile_index) != terra::crs(aoi)) {
        cat("CRS mismatch. Reprojecting AOI to match the tile index CRS.\n")
        aoi <- terra::project(aoi, terra::crs(tile_index))
    } else {
        cat("CRS match. No reprojection needed.\n")
    }

    # --- 3. Filter Rasters by Overlap ---
    cat("Finding intersecting raster footprints...\n")
    candidates <- tile_index[aoi, ]

    if (nrow(candidates) == 0) {
        message(
            "No rasters were found intersecting the AOI. The function will now stop."
        )
        return(invisible(character(0)))
    }
    cat(
        "Found",
        nrow(candidates),
        "candidate rasters. Calculating overlap percentage...\n"
    )

    aoi_area <- terra::expanse(aoi)
    final_raster_list <- c()

    for (i in 1:nrow(candidates)) {
        footprint <- candidates[i, ]
        intersection_geom <- terra::intersect(aoi, footprint)

        if (nrow(intersection_geom) > 0) {
            overlap_ratio <- terra::expanse(intersection_geom) / aoi_area
            if (overlap_ratio >= overlap_threshold) {
                final_raster_list <- c(final_raster_list, footprint$location)
            }
        }
    }

    if (length(final_raster_list) == 0) {
        message(
            "No rasters met the required ",
            overlap_threshold * 100,
            "% overlap threshold. The function will now stop."
        )
        return(invisible(character(0)))
    }
    cat(
        "\nFound",
        length(final_raster_list),
        "rasters that meet the overlap criteria.\n"
    )

    # --- 4. Crop and Save Qualifying Rasters ---
    cat("--- Starting the cropping process ---\n")
    newly_created_files <- c()

    for (i in 1:length(final_raster_list)) {
        raster_path <- final_raster_list[i]

        output_filename <- file.path(
            output_dir,
            paste0(aoi_name, "_", basename(raster_path))
        )

        # Check if cropped file already exists
        if (file.exists(output_filename)) {
            cat(sprintf(
                "Skipping %d of %d: %s (already exists)\n",
                i,
                length(final_raster_list),
                basename(output_filename)
            ))
            newly_created_files <- c(newly_created_files, output_filename)
            next
        }

        cat(sprintf(
            "Processing %d of %d: %s\n",
            i,
            length(final_raster_list),
            basename(raster_path)
        ))

        original_raster <- terra::rast(raster_path)
        crs_raster <- terra::crs(original_raster)
        aoi_projected <- terra::project(aoi, crs_raster)
        cropped_raster <- terra::crop(
            original_raster,
            aoi_projected,
            mask = TRUE
        )

        terra::writeRaster(cropped_raster, output_filename, overwrite = TRUE)

        newly_created_files <- c(newly_created_files, output_filename)
    }

    cat("----------------------------------------------------------\n")
    cat("Success! All tasks complete.\n")
    cat(length(newly_created_files), "cropped rasters have been saved in:\n")
    cat(output_dir, "\n")
    cat("----------------------------------------------------------\n")

    return(invisible(newly_created_files))
}
