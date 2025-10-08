#' Find Rasters Intersecting an AOI (Polygon or Points)
#'
#' This function identifies raster files from a tile index that intersect with a
#' given Area of Interest (AOI), which can be a polygon or a set of points. It
#' returns a character vector of the full paths to the qualifying raster files.
#'
#' @param aoi_path A character string. The full path to the spatial file
#'   (e.g., GeoPackage, Shapefile) defining your Area of Interest.
#' @param tile_index_path A character string. The full path to the master vector
#'   file (e.g., GeoPackage, Shapefile) containing the footprints of all rasters.
#' @param overlap_threshold A numeric value between 0 and 1. If the AOI is a
#'   polygon, this specifies the minimum required overlap as a proportion of the
#'   AOI's total area. Defaults to 0.5. Ignored for point AOIs.
#'
#' @return A character vector of full paths to the raster files that meet the
#'   intersection criteria. Returns an empty character vector if no rasters are found.
#' @export
gaza_find_rasters_for_aoi <- function(
    aoi_path,
    tile_index_path,
    overlap_threshold = 0.5
) {
    # --- 1. Input Validation ---
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop(
            "Package 'terra' is required but not installed. Please run: install.packages('terra')"
        )
    }

    stopifnot(
        "Error: aoi_path does not exist." = file.exists(aoi_path),
        "Error: tile_index_path does not exist." = file.exists(tile_index_path),
        "Error: overlap_threshold must be between 0 and 1." = is.numeric(
            overlap_threshold
        ) &&
            overlap_threshold >= 0 &&
            overlap_threshold <= 1
    )

    # --- 2. Find Intersecting Rasters ---
    cat("--- Finding Intersecting Rasters ---\n")

    # Load spatial data
    aoi <- terra::vect(aoi_path)
    tile_index <- terra::vect(tile_index_path)

    # Ensure CRS Consistency
    if (terra::crs(tile_index) != terra::crs(aoi)) {
        cat("CRS mismatch. Reprojecting AOI to match the tile index CRS.\n")
        aoi <- terra::project(aoi, terra::crs(tile_index))
    }

    # Find candidates by spatial intersection
    candidates <- tile_index[aoi, ]
    if (nrow(candidates) == 0) {
        message("No rasters were found intersecting the AOI.")
        return(character(0))
    }

    aoi_geom_type <- terra::geomtype(aoi)
    final_raster_list <- character(0)

    if (grepl("polygon", aoi_geom_type, ignore.case = TRUE)) {
        # Polygon AOI: Filter by overlap threshold
        cat(
            nrow(candidates),
            "candidate rasters found. Filtering by overlap threshold...\n"
        )
        aoi_area <- terra::expanse(aoi)
        for (i in 1:nrow(candidates)) {
            footprint <- candidates[i, ]
            intersection_geom <- terra::intersect(aoi, footprint)
            if (nrow(intersection_geom) > 0) {
                overlap_ratio <- terra::expanse(intersection_geom) / aoi_area
                if (overlap_ratio >= overlap_threshold) {
                    final_raster_list <- c(
                        final_raster_list,
                        footprint$location
                    )
                }
            }
        }
    } else {
        # Point AOI: Keep all intersecting candidates
        cat(nrow(candidates), "raster footprints intersect the input points.\n")
        final_raster_list <- candidates$location
    }

    if (length(final_raster_list) == 0) {
        message("No rasters met the required criteria.")
    } else {
        cat("Found", length(final_raster_list), "rasters to process.\n")
    }

    return(final_raster_list)
}


#' Crop a List of Rasters to an AOI
#'
#' This function takes a list of raster file paths, crops them to the extent of
#' a given Area of Interest (AOI), and saves the results to a specified directory.
#'
#' @param raster_list A character vector of full paths to the raster files that
#'   you want to crop.
#' @param aoi_path A character string. The full path to the spatial file
#'   (e.g., GeoPackage, Shapefile) defining the cropping extent.
#' @param output_dir A character string. The path to the directory where the
#'   newly cropped rasters will be saved. The directory will be created if it
#'   does not exist.
#' @param aoi_name A character string used as a prefix for the cropped output files.
#'   For example, `aoi_name = "gaza_city"` results in `gaza_city_<raster_name>`.
#'
#' @return Invisibly returns a character vector containing the full paths to the
#'   newly created cropped raster files.
#' @export
gaza_crop_rasters_for_aoi <- function(
    raster_list,
    aoi_path,
    output_dir,
    aoi_name = "cropped"
) {
    # --- 1. Input Validation ---
    if (!requireNamespace("terra", quietly = TRUE)) {
        stop(
            "Package 'terra' is required but not installed. Please run: install.packages('terra')"
        )
    }

    stopifnot(
        "Error: aoi_path does not exist." = file.exists(aoi_path),
        "Error: raster_list must be a character vector of file paths." = !is.null(
            raster_list
        ) &&
            is.character(raster_list) &&
            length(raster_list) > 0,
        "Error: output_dir must be provided." = !is.null(output_dir)
    )

    if (length(raster_list) == 0) {
        message("The provided raster_list is empty. No rasters to crop.")
        return(invisible(character(0)))
    }

    # --- 2. Setup ---
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
        cat("Created output directory at:", output_dir, "\n")
    }

    aoi <- terra::vect(aoi_path)
    newly_created_files <- c()

    # --- 3. Crop and Save Rasters ---
    cat("--- Starting the cropping process ---\n")
    for (i in 1:length(raster_list)) {
        raster_path <- raster_list[i]

        if (!file.exists(raster_path)) {
            warning(paste("File not found, skipping:", raster_path))
            next
        }

        output_filename <- file.path(
            output_dir,
            paste0(aoi_name, "_", basename(raster_path))
        )

        if (file.exists(output_filename)) {
            cat(sprintf(
                "Skipping %d of %d: %s (already exists)\n",
                i,
                length(raster_list),
                basename(output_filename)
            ))
            newly_created_files <- c(newly_created_files, output_filename)
            next
        }

        cat(sprintf(
            "Processing %d of %d: %s\n",
            i,
            length(raster_list),
            basename(raster_path)
        ))

        original_raster <- terra::rast(raster_path)
        aoi_projected <- terra::project(aoi, terra::crs(original_raster))

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
