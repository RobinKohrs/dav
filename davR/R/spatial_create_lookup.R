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
#'
#' @return Invisibly returns a list containing the paths to the generated
#'   `main.csv` file and the directory of group CSVs. This is primarily for
#'   programmatic use; the main effect is writing files to disk.
#'
#' @importFrom terra rast project as.polygons centroids crds ext geom
#' @importFrom dplyr group_by summarise rename mutate select left_join bind_cols
#' @importFrom tidyr pivot_wider
#' @importFrom purrr walk
#' @importFrom readr write_csv
#' @importFrom stats kmeans
#' @importFrom rlang .data
#' @importFrom sf st_as_sf st_buffer
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
create_spatial_lookup = function(input_raster_file,
                                 output_base_dir,
                                 n_groups = 500,
                                 crs_output = "EPSG:4326",
                                 seed = 123) {

  # 1. --- Input Validation ---
  if (!file.exists(input_raster_file)) {
    stop("Input raster file not found at: ", input_raster_file)
  }
  if (!is.numeric(n_groups) || n_groups < 1) {
    stop("`n_groups` must be a positive integer.")
  }
  if (!dir.exists(output_base_dir)) {
    message("Output directory does not exist. Creating it at: ", output_base_dir)
    dir.create(output_base_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # 2. --- Prepare Directories and Paths ---
  lookups_dir = file.path(output_base_dir, "lookups")
  grid_cells_dir = file.path(lookups_dir, "grid_cells")
  main_lookup_path = file.path(lookups_dir, "main.csv")

  dir.create(grid_cells_dir, recursive = TRUE, showWarnings = FALSE)

  # 3. --- Load and Process Raster Data ---
  message("--> Loading raster and converting to polygons...")
  initial_raster = terra::rast(input_raster_file)
  
  # Print raster information for debugging
  message("    Raster dimensions: ", terra::nrow(initial_raster), " rows x ", 
          terra::ncol(initial_raster), " columns")
  message("    Number of layers: ", terra::nlyr(initial_raster))
  
  # Check for NA values in the first layer
  first_layer = initial_raster[[1]]
  na_count = sum(is.na(terra::values(first_layer)))
  total_cells = terra::ncell(first_layer)
  message("    NA values in first layer: ", na_count, " out of ", total_cells, 
          " cells (", round(na_count/total_cells * 100, 1), "%)")
  
  # Project to target CRS
  projected_raster = terra::project(initial_raster, crs_output)
  first_layer_proj = projected_raster[[1]]
  
  # Create a grid of cell centroids for all non-NA cells
  message("    Creating cell centroids for valid cells...")
  valid_cells = !is.na(terra::values(first_layer_proj))
  cell_numbers = which(valid_cells)
  
  # Get coordinates for all valid cells
  cell_coords = terra::xyFromCell(first_layer_proj, cell_numbers)
  cell_ids = paste0("c_", cell_numbers)
  
  # Create a simple features data frame with points
  points_df = data.frame(
    cell_id = cell_ids,
    x = cell_coords[,1],
    y = cell_coords[,2]
  )
  
  # Create a simple features object with points
  points_sf = sf::st_as_sf(points_df, coords = c("x", "y"), crs = crs_output)
  
  # Convert points to polygons by creating a buffer
  message("    Converting points to polygons...")
  cell_size = terra::res(first_layer_proj)
  buffer_size = min(cell_size) / 2
  fine_polygons = sf::st_buffer(points_sf, buffer_size)
  
  # Convert back to terra format for consistency
  fine_polygons = terra::vect(fine_polygons)
  
  message("    Total valid cells processed: ", nrow(fine_polygons))
  
  if (nrow(fine_polygons) < 100) {
    warning("Very few valid polygons (", nrow(fine_polygons), 
            "). This might indicate an issue with the data processing.")
  }
  
  # 4. --- Group Cells Using K-Means Clustering ---
  message("--> Clustering ", nrow(fine_polygons), " cells into ", n_groups, " groups...")
  centroids = terra::centroids(fine_polygons)
  centroid_coords = terra::crds(centroids)

  set.seed(seed)
  kmeans_result = stats::kmeans(centroid_coords, centers = n_groups, nstart = 25)
  fine_polygons$group_id = kmeans_result$cluster

  # 5. --- Extract Coordinates and Create Master Data Frame ---
  message("--> Extracting coordinates and bounding boxes...")
  
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

  # Write individual group files
  message("--> Writing individual group files to: ", grid_cells_dir)
  master_df %>%
    dplyr::group_by(.data$group_id) %>%
    dplyr::group_split() %>%
    purrr::walk(function(group_data) {
      current_group_id = group_data$group_id[1]
      file_path = file.path(grid_cells_dir, paste0("g_", current_group_id, ".csv"))
      output_data = dplyr::select(group_data, -.data$group_id)
      readr::write_csv(output_data, file_path)
    })

  # Write main lookup file
  message("--> Writing main lookup file to: ", main_lookup_path)
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
  message("\nProcessing complete!")
  
  # Return file paths invisibly for programmatic use
  invisible(list(
    main_lookup = main_lookup_path,
    group_dir = grid_cells_dir
  ))
}