# --- Options ---
# options(timeout = 999999) # Can be set elsewhere, e.g., .Rprofile or interactively

# --- Constants ---
AUSTRIA_BBOX = list(
  lon_min = 8.1,
  lon_max = 17.74,
  lat_min = 45.5,
  lat_max = 49.48
)

# -------------------------------------------------------------------------
# Helper: Get the latest file from a remote server (Unchanged)
# -------------------------------------------------------------------------
get_latest_file_info = function(host = c("nwp", "nowcast", "ensemble"), base_url = "ftp://eaftp.zamg.ac.at/") {
  host = match.arg(host)
  host_url = paste0(base_url, host, "/")
  cli::cli_alert_info("Checking for latest file at: {.url {host_url}}")

  tryCatch({
    current_files_raw = RCurl::getURL(
      url = host_url,
      verbose = FALSE,
      ftp.use.epsv = TRUE,
      dirlistonly = TRUE
    )

    files_clean = strsplit(current_files_raw, "[\r\n]+")[[1]]
    files_clean = files_clean[files_clean != ""] # Remove empty entries if any

    if (length(files_clean) == 0) {
      cli::cli_abort("No files found at {.url {host_url}}.")
    }

    latest_file = sort(files_clean)[length(files_clean)]
    cli::cli_alert_success("Found latest file: {.file {latest_file}}")

    return(list(
      name = latest_file,
      remote_path = file.path(host_url, latest_file)
    ))
  }, error = function(e) {
    cli::cli_abort("Failed to list files at {.url {host_url}}. Error: {e$message}")
  })
}

# -------------------------------------------------------------------------
# Helper: Download file if it doesn't exist locally (Unchanged logic)
# -------------------------------------------------------------------------
download_if_needed = function(remote_path, local_path) {
  # local_path is now pre-determined (can be temp or permanent)
  if (!file.exists(local_path)) {
    # Ensure directory exists (needed for both temp and permanent paths)
    dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("Downloading {.url {remote_path}} to {.path {local_path}}...")
    tryCatch({
      # Use base R for download
      download.file(remote_path, destfile = local_path, mode = "wb", quiet = FALSE)
      cli::cli_alert_success("Download complete.")
    }, error = function(e) {
      # Clean up potentially partially downloaded file on error? Maybe not necessary.
      cli::cli_abort("Download failed: {e$message}")
    })
  } else {
    cli::cli_alert_info("Source file already exists locally: {.path {local_path}}")
  }
  # Use base R invisible
  invisible(local_path)
}

# -------------------------------------------------------------------------
# Helper: Read raster, filter level, adjust time (Returns SpatRaster - Unchanged)
# -------------------------------------------------------------------------
load_and_prepare_raster = function(local_path,
                                   subdatasets = NULL,
                                   level = NULL,
                                   timezone = "Europe/Paris") {

  cli::cli_alert_info("Loading raster from {.path {local_path}}...")
  if (!is.null(subdatasets)) {
    cli::cli_alert("Attempting to load specified subdataset(s): {.val {paste(subdatasets, collapse=', ')}}")
  } else {
    cli::cli_alert("No subdatasets specified, loading default/first.")
  }

  # Load the raster
  data = tryCatch({
    terra::rast(local_path, subds = subdatasets)
  }, error = function(e) {
    cli::cli_abort("Failed to load raster from {.path {local_path}}. Error: {e$message}")
  })

  # Select specific level if requested
  if (!is.null(level)) {
    cli::cli_alert("Filtering by level: {.val {level}}")
    base_var = names(data)[1]
    if (!is.null(subdatasets)) base_var = subdatasets[1]
    base_var = sub("(_level=[0-9]+)$", "", base_var)
    level_pattern = glue::glue("(?i)^{base_var}_level={level}$")
    level_indices = grep(level_pattern, names(data), perl = TRUE)

    if (length(level_indices) > 0) {
      cli::cli_alert_success("Found {length(level_indices)} layer(s) matching level pattern.")
      data = data[[level_indices]]
    } else {
      cli::cli_warn("Level pattern {.val {level_pattern}} did not match any layer names: {.val {paste(names(data), collapse=', ')}}. Returning raster without level filtering.")
    }
  }

  # Adjust time dimension
  times = terra::time(data)
  if (length(times) > 0 && !all(is.na(times))) {
    cli::cli_alert_info("Adjusting raster time to timezone: {.val {timezone}}")
    tryCatch({
      times_converted = lubridate::with_tz(times, timezone)
      terra::`time<-`(data, times_converted) # Explicit assignment
      cli::cli_alert_success("Time adjustment complete.")
    }, error = function(e){
      cli::cli_warn("Failed to convert time zone: {e$message}")
    })
  } else {
    cli::cli_alert_warning("No valid time information found in the raster layers.")
  }

  return(data)
}


# -------------------------------------------------------------------------
# Helper: Extract data for a specific point from a SpatRaster (Unchanged)
# -------------------------------------------------------------------------
extract_point_data = function(raster_data, x, y, timezone) {

  cli::cli_alert_info("Extracting data for point (Lon: {x}, Lat: {y}).")

  # --- CRS Handling ---
  crs_raster = terra::crs(raster_data)
  point_matrix = matrix(c(x, y), ncol = 2)
  point_wgs84 = terra::vect(point_matrix, crs = "EPSG:4326")
  cli::cli_alert("Input point CRS assumed: {.val EPSG:4326 (WGS84)}")
  cli::cli_alert("Raster CRS: {.val {crs_raster}}")

  if (!terra::same.crs(point_wgs84, raster_data)) {
    cli::cli_alert("Projecting point coordinates to raster CRS...")
    point_target_crs = tryCatch({
      terra::project(point_wgs84, crs_raster)
    }, error = function(e) {
      cli::cli_abort("Failed to project point coordinates: {e$message}")
    })
    cli::cli_alert_success("Point projection complete.")
  } else {
    point_target_crs = point_wgs84
    cli::cli_alert("Point and raster CRS match, no projection needed.")
  }

  # --- Extraction ---
  extracted_raw = tryCatch({
    terra::extract(raster_data, point_target_crs, ID = FALSE)
  }, error = function(e) {
    cli::cli_abort("Failed to extract data at point: {e$message}")
  })

  if ( (is.matrix(extracted_raw) || is.data.frame(extracted_raw)) && (nrow(extracted_raw) == 0 || all(is.na(extracted_raw[1, ]))) ) {
    cli::cli_abort("Point (Lon: {x}, Lat: {y}) appears to be outside the actual data extent of the raster after projection, or extraction yielded only NAs.")
  } else if (!is.matrix(extracted_raw) && !is.data.frame(extracted_raw)) {
    cli::cli_warn("Unexpected structure returned by terra::extract. Attempting to proceed.")
  }

  # --- Formatting ---
  times_final = terra::time(raster_data)
  value_vector = as.numeric(extracted_raw[1, ])

  if (length(value_vector) != length(times_final)) {
    cli::cli_warn("Mismatch between number of extracted values ({length(value_vector)}) and time steps ({length(times_final)}). Check raster structure and extraction.")
  }

  df = data.frame(
    value = value_vector,
    time = times_final
  )

  cli::cli_alert_success("Data extraction and formatting complete.")
  return(df)
}


# -------------------------------------------------------------------------
# Main Wrapper Function (Updated download_dir logic and result saving)
# -------------------------------------------------------------------------
#' @title Get Weather Forecast Data from GeoSphere Austria
#' @description Downloads the latest forecast data (NWP, Nowcast, or Ensemble)
#'   and either returns the full raster dataset or extracts a time series
#'   for a specific point. Optionally saves the processed result to disk.
#'
#' @param host Character. The data source: `"nwp"`, `"nowcast"`, or `"ensemble"`.
#' @param x Numeric. Optional. Longitude coordinate (in WGS84, decimal degrees)
#'   for point data extraction. If `NULL` (default) or invalid, the full raster is returned.
#' @param y Numeric. Optional. Latitude coordinate (in WGS84, decimal degrees)
#'   for point data extraction. If `NULL` (default) or invalid, the full raster is returned.
#' @param level Optional. The vertical level to filter for (e.g., 850 hPa).
#'   Filtering depends on layer naming conventions in the source file.
#' @param subdatasets Optional. Character vector of subdatasets (variables)
#'   to load (e.g., `"T"`, `"U"`, `"V"`). If `NULL` (default), `terra::rast`
#'   attempts to load the first/default subdataset(s).
#' @param download_dir Character or NULL. Optional. Path to a directory for storing
#'   downloaded *source* files (allows caching) and saving the *processed results*.
#'   If `NULL` (default), source files are downloaded to a temporary location
#'   (and removed at session end) and results are not saved to disk. If a path
#'   is provided, the processed result (raster or point data) will be saved
#'   there using a timestamped name (e.g., `YYYYMMDD_HHMMSS_<host>_raster.nc`
#'   or `YYYYMMDD_HHMMSS_<host>_point.csv`).
#' @param timezone Character. The target timezone for the time information
#'   (e.g., `"Europe/Vienna"`, `"UTC"`). Defaults to `"Europe/Paris"`.
#'
#' @return If valid `x` and `y` coordinates within the approximate Austrian
#'   bounding box are provided, returns a `data.frame` with columns `value`
#'   and `time`. Otherwise, returns a `terra::SpatRaster` object containing
#'   the requested forecast data layers. In both cases, if `download_dir` was
#'   specified, the returned object will also be saved to that directory.
#'
#' @export
#' @examples
#' \dontrun{
#' # --- Examples ---
#'
#' # Example 1: Get point data for Vienna, use temp download, return df
#' vienna_lon = 16.3738
#' vienna_lat = 48.2082
#' nwp_vienna_point_mem = geosphere_get_forecast(host = "nwp",
#'                                               x = vienna_lon, y = vienna_lat,
#'                                               timezone = "Europe/Vienna",
#'                                               download_dir = NULL) # Explicitly NULL
#' if (inherits(nwp_vienna_point_mem, "data.frame")) {
#'   print(head(nwp_vienna_point_mem))
#' }
#'
#' # Example 2: Get point data, specify dir, save CSV, return df
#' my_dir = "my_forecast_data"
#' nwp_vienna_point_disk = geosphere_get_forecast(host = "nwp",
#'                                                x = vienna_lon, y = vienna_lat,
#'                                                timezone = "Europe/Vienna",
#'                                                download_dir = my_dir)
#' # Check if the CSV file exists in my_dir
#' list.files(my_dir, pattern = "\\.csv$")
#'
#' # Example 3: Get full raster, specify dir, save NetCDF, return SpatRaster
#' ensemble_t850_raster_disk = geosphere_get_forecast(host = "ensemble",
#'                                                    x = NULL, y = NULL,
#'                                                    subdatasets = "T",
#'                                                    level = 850,
#'                                                    timezone = "UTC",
#'                                                    download_dir = my_dir)
#' # Check if the NetCDF file exists in my_dir
#' list.files(my_dir, pattern = "\\.nc$")
#' if (inherits(ensemble_t850_raster_disk, "SpatRaster")) {
#'   print(ensemble_t850_raster_disk)
#' }
#'
#' # Example 4: Get full raster, use temp download, return SpatRaster
#' nowcast_raster_mem = geosphere_get_forecast(host = "nowcast", download_dir = NULL)
#' if (inherits(nowcast_raster_mem, "SpatRaster")) {
#'    print(nowcast_raster_mem)
#' }
#'
#' }
geosphere_get_forecast = function(host,
                                  x = NULL,
                                  y = NULL,
                                  level = NULL,
                                  subdatasets = NULL,
                                  download_dir = NULL, # Default changed to NULL
                                  timezone = "Europe/Paris") {

  cli::cli_h1("Starting GeoSphere Forecast Retrieval")

  # --- Validate Host ---
  host_options = c("nwp", "nowcast", "ensemble")
  if (!(host %in% host_options)) {
    cli::cli_abort("Invalid {.arg host} specified. Must be one of {.val {host_options}}.")
  }

  # --- Coordinate Check & Mode Determination ---
  extract_point = FALSE
  if (!is.null(x) && !is.null(y)) {
    if (!is.numeric(x) || !is.numeric(y) || length(x) != 1 || length(y) != 1) {
      cli::cli_warn("Input {.arg x} and {.arg y} must be single numeric values. Proceeding to return the full raster.")
    } else {
      if (x >= AUSTRIA_BBOX$lon_min && x <= AUSTRIA_BBOX$lon_max &&
          y >= AUSTRIA_BBOX$lat_min && y <= AUSTRIA_BBOX$lat_max) {
        extract_point = TRUE
        cli::cli_alert_info("Coordinates (Lon: {x}, Lat: {y}) are within the approximate Austrian bounding box.")
        cli::cli_alert("Will attempt to extract point data.")
      } else {
        cli::cli_warn("Coordinates (Lon: {x}, Lat: {y}) are outside the approximate Austrian bounding box. Proceeding to return the full raster.")
      }
    }
  } else {
    if (!is.null(x) || !is.null(y)) {
      cli::cli_warn("Only one coordinate ({.arg x} or {.arg y}) provided. Provide both or none. Proceeding to return the full raster.")
    } else {
      cli::cli_alert_info("No coordinates provided. Will return the full raster dataset.")
    }
  }
  if (!extract_point) {
    cli::cli_alert("To extract data for a specific point, provide valid {.arg x} and {.arg y} coordinates within the region.")
  } else {
    cli::cli_alert("To get the full raster, set {.code x = NULL} and {.code y = NULL}.")
  }

  # --- Get File Info ---
  latest_file = get_latest_file_info(host)

  # --- Determine Download Path & Saving ---
  save_result = !is.null(download_dir)
  current_time_str = format(Sys.time(), "%Y%m%d_%H%M%S") # Timestamp for saving results

  if (save_result) {
    # Create specified directory if it doesn't exist
    if (!dir.exists(download_dir)) {
      cli::cli_alert_info("Creating specified download directory: {.path {download_dir}}")
      dir.create(download_dir, recursive = TRUE, showWarnings = FALSE)
    }
    # Path for the *source* file download (allows caching)
    source_local_path = file.path(download_dir, host, latest_file$name)
    # Ensure the host-specific subdirectory exists within download_dir
    dir.create(dirname(source_local_path), recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("Using persistent path for source file: {.path {source_local_path}}")
    cli::cli_alert_info("Processed results will be saved to: {.path {download_dir}}")

  } else {
    # Path for the *source* file download (temporary)
    # Use tempfile to guarantee uniqueness and place in session temp dir
    source_local_path = tempfile(pattern = paste0(current_time_str, "_", host, "_"), fileext = ".nc")
    cli::cli_alert_info("Using temporary path for source download: {.path {source_local_path}}")
    cli::cli_alert_info("Processed results will not be saved to disk.")
  }

  # --- Download Source File ---
  download_if_needed(latest_file$remote_path, source_local_path)

  # --- Load and Prepare Raster Data ---
  prepared_raster = load_and_prepare_raster(source_local_path,
                                            subdatasets = subdatasets,
                                            level = level,
                                            timezone = timezone)

  # --- Conditional Return & Saving ---
  if (extract_point) {
    # Extract point data
    result_data = extract_point_data(prepared_raster, x, y, timezone)

    # Save result if requested
    if (save_result) {
      output_filename = glue::glue("{current_time_str}_{host}_point.csv")
      output_path = file.path(download_dir, output_filename)
      cli::cli_alert_info("Saving point data to {.path {output_path}}")
      tryCatch({
        # Use base R write.csv
        utils::write.csv(result_data, output_path, row.names = FALSE, quote = TRUE)
        cli::cli_alert_success("CSV saved.")
      }, error = function(e) {
        cli::cli_warn("Failed to save CSV result: {e$message}")
      })
    }
    cli::cli_h1("Forecast retrieval complete (Point Data).")
    # Clean up temporary source file if we used one
    if (!save_result && file.exists(source_local_path)) {
      unlink(source_local_path)
    }
    return(result_data) # Return data.frame

  } else {
    # Result is the prepared raster itself
    result_raster = prepared_raster

    # Save result if requested
    if (save_result) {
      output_filename = glue::glue("{current_time_str}_{host}_raster.nc")
      output_path = file.path(download_dir, output_filename)
      cli::cli_alert_info("Saving raster data to {.path {output_path}}")
      tryCatch({
        # Overwrite = TRUE is often convenient, but consider consequences
        terra::writeRaster(result_raster, output_path, overwrite = TRUE, filetype = "NetCDF")
        cli::cli_alert_success("Raster saved as NetCDF.")
      }, error = function(e) {
        cli::cli_warn("Failed to save raster result: {e$message}")
      })
    }
    cli::cli_h1("Forecast retrieval complete (Raster Data).")
    # Clean up temporary source file if we used one
    if (!save_result && file.exists(source_local_path)) {
      unlink(source_local_path)
    }
    return(result_raster) # Return SpatRaster
  }
}
