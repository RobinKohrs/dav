#' Create a two-level spatial lookup from a geospatial raster
#'
#' @description
#' This function processes a geospatial raster file (e.g., GeoTIFF or NetCDF)
#' to generate a two-level lookup structure suitable for web applications. It
#' partitions the raster cells into a specified number of spatially coherent
#' groups using k-means clustering and exports the data as a series of CSV files.
#'
#' The output consists of:
#' 1. A main index file (`main.csv`) containing the overall bounding box for
#'    each group.
#' 2. A directory of individual group files (`g_*.csv`), where each file
#'    contains the detailed coordinates and bounding box for every cell within
#'    that group.
#'
#' @param input_raster_file A string path to the input raster file.
#'   Must be a format readable by `terra::rast()`.
#' @param output_base_dir A string path to the directory where the output
#'   `lookups` folder will be created.
#' @param n_groups The target number of groups (clusters) to partition the
#'   raster cells into. This determines the number of rows in `main.csv`.
#' @param crs_output The target Coordinate Reference System (CRS) for the output
#'   data, specified as an EPSG string (e.g., "EPSG:4326"). Defaults to WGS 84,
#'   the standard for web maps.
#' @param seed An integer to set the random seed for k-means clustering,
#'   ensuring reproducible results. Defaults to 123.
#' @param resampling_method The resampling method for reprojection. Defaults to
#'  "bilinear". Use "near" for categorical data. See `terra::project`.
#'
#' @return Invisibly returns a list containing the paths to the generated
#'   `main.csv` file, the directory of group CSVs, the path to the grid vector file,
#'   and the path to the reprojected raster file.
#'
#' @importFrom terra rast project as.polygons centroids crds ext geom writeRaster
#' @importFrom dplyr group_by summarise rename mutate select left_join bind_cols
#' @importFrom tidyr pivot_wider
#' @importFrom purrr walk
#' @importFrom readr write_csv
#' @importFrom stats kmeans
#' @importFrom rlang .data
#' @importFrom sf st_as_sf st_write
#' @importFrom cli cli_h1 cli_alert_info cli_alert_success cli_warn
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a dummy raster file for the example
#' r = terra::rast(xmin = 9, xmax = 17, ymin = 46, ymax = 49,
#'                  resolution = 0.01, crs = "EPSG:4326")
#' r[] = 1:terra::ncell(r)
#' temp_raster_path = file.path(tempdir(), "austria_dummy.tif")
#' terra::writeRaster(r, temp_raster_path)
#'
#' # Define an output directory
#' temp_output_dir = file.path(tempdir(), "my_app_data")
#'
#' # Run the function
#' create_spatial_lookup(
#'   input_raster_file = temp_raster_path,
#'   output_base_dir = temp_output_dir,
#'   n_groups = 50
#' )
#'
#' # Check the output
#' list.files(file.path(temp_output_dir, "lookups"))
#' list.files(file.path(temp_output_dir, "lookups", "grid_cells"))
#' }
spatial_create_lookup = function(input_raster_file,
                                 output_base_dir,
                                 n_groups = 500,
                                 crs_output = "EPSG:4326",
                                 seed = 123,
                                 resampling_method = "bilinear") {

  # 1. --- Input Validation ---
  if (!file.exists(input_raster_file)) {
    stop("Input raster file not found at: ", input_raster_file)
  }
  if (!is.numeric(n_groups) || n_groups < 1) {
    stop("`n_groups` must be a positive integer.")
  }
  if (!dir.exists(output_base_dir)) {
    cli::cli_alert_info("Output directory does not exist. Creating it at: {.path {output_base_dir}}")
    dir.create(output_base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # 2. --- Prepare Directories and Paths ---
  lookups_dir = file.path(output_base_dir, "lookups")
  grid_cells_dir = file.path(lookups_dir, "grid_cells")
  main_lookup_path = file.path(lookups_dir, "main.csv")

  dir.create(grid_cells_dir, recursive = TRUE, showWarnings = FALSE)

  # 3. --- Load and Process Raster Data ---
  cli::cli_h1("Processing Raster")
  cli::cli_alert_info("Loading raster and converting to polygons...")
  initial_raster = terra::rast(input_raster_file)

  # Print raster information for debugging
  cli::cli_alert_info(c(
    "    Raster dimensions: {terra::nrow(initial_raster)} rows x {terra::ncol(initial_raster)} columns",
    "    Number of layers: {terra::nlyr(initial_raster)}"
  ))

  # Check for NA values in the first layer
  first_layer = initial_raster[[1]]
  na_count = sum(is.na(terra::values(first_layer)))
  total_cells = terra::ncell(first_layer)
  cli::cli_alert_info("    NA values in first layer: {na_count} out of {total_cells} cells ({round(na_count/total_cells * 100, 1)}%)")

  # Project to target CRS
  cli::cli_alert_info("Reprojecting raster to {crs_output} using '{resampling_method}' method...")
  projected_raster = terra::project(initial_raster, crs_output, method = resampling_method)
  first_layer_proj = projected_raster[[1]]

  # Convert valid raster cells to polygons directly
  cli::cli_alert_info("Converting raster cells to polygons...")
  fine_polygons = terra::as.polygons(first_layer_proj, dissolve = FALSE, na.rm = TRUE)

  # Assign cell IDs based on their original cell number
  centroids_of_polys = terra::centroids(fine_polygons)
  cell_numbers = terra::cellFromXY(first_layer_proj, terra::crds(centroids_of_polys))
  fine_polygons$cell_id = paste0("c_", cell_numbers)

  cli::cli_alert_info("Total valid cells processed: {nrow(fine_polygons)}")

  if (nrow(fine_polygons) < 100) {
    cli::cli_warn("Very few valid polygons ({nrow(fine_polygons)}). This might indicate an issue with the data processing.")
  }

  # 4. --- Group Cells Using K-Means Clustering ---
  cli::cli_h1("Clustering")
  cli::cli_alert_info("Clustering {nrow(fine_polygons)} cells into {n_groups} groups...")
  centroids = terra::centroids(fine_polygons)
  centroid_coords = terra::crds(centroids)

  set.seed(seed)
  kmeans_result = stats::kmeans(centroid_coords, centers = n_groups, nstart = 25)
  fine_polygons$group_id = kmeans_result$cluster

  # 5. --- Extract Coordinates and Create Master Data Frame ---
  cli::cli_h1("Extracting Geometries")
  cli::cli_alert_info("Extracting coordinates and bounding boxes...")

  # Extract bounding boxes properly
  bboxes = as.data.frame(terra::geom(fine_polygons, df = TRUE)) %>%
    dplyr::group_by(.data$geom) %>%
    dplyr::summarise(
      xmin = min(.data$x, na.rm = TRUE),
      ymin = min(.data$y, na.rm = TRUE),
      xmax = max(.data$x, na.rm = TRUE),
      ymax = max(.data$y, na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    dplyr::select(-.data$geom)

  # Get corners for each polygon
  corners_long = terra::geom(fine_polygons, df = TRUE)

  corners_wide = corners_long %>%
    dplyr::group_by(.data$geom) %>%
    dplyr::mutate(vertex = dplyr::row_number()) %>%
    dplyr::ungroup() %>%
    dplyr::filter(.data$vertex <= 4) %>%
    tidyr::pivot_wider(
      id_cols = "geom",
      names_from = "vertex",
      values_from = c("x", "y"),
      names_glue = "{.value}_{vertex}"
    )

  master_df = dplyr::tibble(
    id = fine_polygons$cell_id,
    group_id = fine_polygons$group_id
  ) %>%
    dplyr::bind_cols(bboxes) %>%
    dplyr::mutate(geom = dplyr::row_number()) %>%
    dplyr::left_join(corners_wide, by = "geom") %>%
    dplyr::select(-.data$geom)

  # 6. --- Generate and Write Output Files ---
  cli::cli_h1("Writing Output Files")

  # Write reprojected raster
  reprojected_raster_path = file.path(lookups_dir, "reprojected_raster.tif")
  cli::cli_alert_info("Writing reprojected raster to: {.path {reprojected_raster_path}}")
  terra::writeRaster(first_layer_proj, reprojected_raster_path, overwrite = TRUE)

  # Create a full sf object with all attributes for the vector grid file
  grid_to_write = fine_polygons %>%
    sf::st_as_sf() %>%
    dplyr::left_join(
      dplyr::select(master_df, -group_id),
      by = c("cell_id" = "id")
    )

  # Write full grid vector file
  grid_vector_path = file.path(lookups_dir, "grid.gpkg")
  cli::cli_alert_info("Writing full grid vector file to: {.path {grid_vector_path}}")
  sf::st_write(grid_to_write, grid_vector_path, driver = "GPKG", delete_dsn = TRUE)

  # Write individual group files
  cli::cli_alert_info("Writing individual group files to: {.path {grid_cells_dir}}")

  grouped_data = master_df %>%
    dplyr::group_by(.data$group_id) %>%
    dplyr::group_split()

  purrr::walk(grouped_data, function(group_data) {
    current_group_id = group_data$group_id[1]
    file_path = file.path(grid_cells_dir, paste0("g_", current_group_id, ".csv"))
    output_data = dplyr::select(group_data, -.data$group_id)
    readr::write_csv(output_data, file_path, progress = FALSE)
  }, .progress = list(
    name = "Writing group files",
    clear = FALSE
  ))

  # Write main lookup file
  cli::cli_alert_info("Writing main lookup file to: {.path {main_lookup_path}}")
  main_lookup_df = master_df %>%
    dplyr::group_by(.data$group_id) %>%
    dplyr::summarise(
      xmin = min(.data$xmin, na.rm = TRUE),
      ymin = min(.data$ymin, na.rm = TRUE),
      xmax = max(.data$xmax, na.rm = TRUE),
      ymax = max(.data$ymax, na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    dplyr::rename(id = .data$group_id)

  readr::write_csv(main_lookup_df, main_lookup_path)

  # 7. --- Finalize and Return ---
  cli::cli_alert_success("Processing complete!")

  # Return file paths invisibly for programmatic use
  invisible(list(
    main_lookup = main_lookup_path,
    group_dir = grid_cells_dir,
    grid_vector = grid_vector_path,
    reprojected_raster = reprojected_raster_path
  ))
}
