#' Download Geosphere Austria Station Metadata
#'
#' @description
#' Retrieves station metadata from the Geosphere Austria API, typically from
#' a dataset's metadata endpoint. Optionally caches the result to a local file.
#'
#' @param metadata_url The full URL to the metadata endpoint of a specific Geosphere
#'   API dataset that contains station information (e.g., ".../metadata").
#'   Defaults to the metadata URL for the "klima-v2-1d" dataset.
#' @param output_path Optional. A file path (e.g., "stations.rds" or "stations.csv")
#'   where the downloaded and processed station data (as an `sf` object or data frame)
#'   should be saved for caching. If the file exists, it will be loaded from the
#'   cache instead of downloading. Using ".rds" is recommended for saving the `sf` object perfectly.
#' @param return_format Character. Either `"sf"` (default) to return an `sf` spatial
#'   data frame or `"dataframe"` to return a regular data frame.
#' @param cache_format Character. Format to use for caching if `output_path` is
#'   provided. Either `"rds"` (default, recommended for `sf` objects) or `"csv"`.
#'   Ignored if `output_path` is `NULL`. Note that saving `sf` objects to CSV
#'   loses spatial information unless WKT geometry is explicitly handled.
#' @param crs Coordinate reference system for the output `sf` object. Defaults to
#'   `4326` (WGS 84), assuming the API provides standard longitude/latitude.
#' @param verbose Logical. If `TRUE`, print informative messages.
#'
#' @return An `sf` spatial data frame (if `return_format = "sf"`) or a regular
#'   data frame (if `return_format = "dataframe"`) containing station metadata.
#'   Returns `NULL` if downloading or processing fails and no cache exists.
#'
#' @importFrom httr GET stop_for_status content http_type status_code
#' @importFrom cli cli_h2 cli_alert_info cli_alert_success cli_alert_danger cli_process_start cli_process_done
#' @importFrom sf st_as_sf st_crs
#' @importFrom tools file_ext
#' @importFrom utils read.csv write.csv
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Ensure sf is installed: install.packages("sf")
#'
#' # Example 1: Get stations as an sf object (default)
#' stations_sf <- geosphere_get_stations(verbose = TRUE)
#' if (!is.null(stations_sf)) {
#'   print(head(stations_sf))
#'   plot(st_geometry(stations_sf))
#' }
#'
#' # Example 2: Get stations as a data frame and cache to RDS
#' stations_df <- geosphere_get_stations(
#'   return_format = "dataframe",
#'   output_path = "geosphere_stations_cache.rds",
#'   cache_format = "rds",
#'   verbose = TRUE
#' )
#' # Next time, it will load from "geosphere_stations_cache.rds" if it exists
#' stations_cached <- geosphere_get_stations(output_path = "geosphere_stations_cache.rds")
#'
#' # Example 3: Use a different metadata URL (replace with a valid one)
#' # custom_url <- "https://dataset.api.hub.geosphere.at/v1/..."
#' # custom_stations <- geosphere_get_stations(metadata_url = custom_url)
#'
#' }
geosphere_get_stations <- function(
    metadata_url = "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v2-1d/metadata",
    output_path = NULL,
    return_format = c("sf", "dataframe"),
    cache_format = c("rds", "csv"),
    crs = 4326,
    verbose = FALSE
) {

  # Validate arguments
  return_format <- match.arg(return_format)
  cache_format <- match.arg(cache_format)

  # --- Caching Logic: Check if file exists ---
  if (!is.null(output_path)) {
    cache_exists <- file.exists(output_path)
    if (cache_exists) {
      if (verbose) cli::cli_alert_info("Loading station data from cache: {.file {output_path}}")
      proc_id <- cli::cli_process_start("Reading cache file")
      tryCatch({
        stations_result <- switch(
          tolower(tools::file_ext(output_path)),
          "rds" = readRDS(output_path),
          "csv" = utils::read.csv(output_path, stringsAsFactors = FALSE),
          # Default: try reading as RDS if extension unknown/mismatched
          readRDS(output_path)
        )
        cli::cli_process_done(proc_id)

        # Ensure return format matches request, even from cache
        if (return_format == "sf" && !inherits(stations_result, "sf")) {
          warning("Cached file is not an 'sf' object, but 'sf' was requested. Returning data frame.", call. = FALSE)
          return(stations_result) # Return as is if conversion isn't trivial/intended
        } else if (return_format == "dataframe" && inherits(stations_result, "sf")) {
          # If sf object is cached but df requested, convert back
          return(sf::st_drop_geometry(stations_result))
        } else {
          return(stations_result)
        }

      }, error = function(e) {
        cli::cli_process_failed(proc_id)
        cli::cli_alert_danger("Failed to read cache file: {.file {output_path}}. Error: {e$message}")
        cli::cli_alert_info("Attempting to download fresh data...")
        # Proceed to download if reading cache failed
      })
    } else {
      if (verbose) cli::cli_alert_info("Cache file not found: {.file {output_path}}. Will download data.")
    }
  }

  # --- Download ---
  if (verbose) cli::cli_h2("Downloading Station Metadata")
  proc_id_down <- cli::cli_process_start("Requesting data from {.url {metadata_url}}")
  response <- tryCatch(
    httr::GET(url = metadata_url),
    error = function(e) {
      cli::cli_process_failed(proc_id_down)
      cli::cli_alert_danger("HTTP request failed. Error: {e$message}")
      return(NULL) # Return NULL on connection failure
    }
  )

  if (is.null(response)) return(NULL) # Exit if GET failed

  # Check for HTTP errors
  http_status <- httr::status_code(response)
  if (http_status >= 400) {
    cli::cli_process_failed(proc_id_down)
    # Try to get error message from content
    err_content <- tryCatch(httr::content(response, as = "text", encoding = "UTF-8"), error = function(e) "")
    cli::cli_alert_danger("HTTP error {http_status} accessing URL.")
    if (nzchar(err_content)) cli::cli_alert_danger("API Response: {err_content}")
    return(NULL) # Return NULL on HTTP error
  } else {
    cli::cli_process_done(proc_id_down)
  }


  # --- Parse Content ---
  proc_id_parse <- cli::cli_process_start("Parsing JSON response")
  metaContent <- tryCatch(
    httr::content(response, as = "parsed", type = "application/json", encoding = "UTF-8"),
    error = function(e) {
      cli::cli_process_failed(proc_id_parse)
      cli::cli_alert_danger("Failed to parse JSON content. Error: {e$message}")
      return(NULL)
    }
  )

  if (is.null(metaContent)) return(NULL)

  # Check expected structure
  if (!is.list(metaContent) || is.null(metaContent$stations) || !is.list(metaContent$stations)) {
    cli::cli_process_failed(proc_id_parse)
    cli::cli_alert_danger("Parsed content missing expected 'stations' list structure.")
    return(NULL)
  }
  cli::cli_process_done(proc_id_parse)


  # --- Process Station List ---
  proc_id_proc <- cli::cli_process_start("Processing station list")

  # Handle case where stations list is empty
  if (length(metaContent$stations) == 0) {
    cli::cli_process_done(proc_id_proc, "No stations found in the metadata.")
    # Return empty structure matching requested format
    if (return_format == "sf") {
      # Create empty sf object with expected geometry type (Point) and CRS
      return(sf::st_sf(geometry = sf::st_sfc(crs = sf::st_crs(crs))))
    } else {
      return(data.frame())
    }
  }

  # Use lapply to process each station's list, converting NULLs to NA
  stations_list <- lapply(metaContent$stations, function(st) {
    for (i in seq_along(st)) {
      if (is.null(st[[i]])) {
        st[[i]] <- NA
      }
    }
    # Ensure core coordinate columns are present before returning the list
    # If they might be missing, add explicit checks here
    # if (!all(c("lon", "lat") %in% names(st))) { warning(...) }
    return(st) # Return the cleaned list
  })

  # Combine the list of lists into a data frame
  # Check column name consistency (using names of the first element)
  col_names <- names(stations_list[[1]])
  stations_list <- lapply(stations_list, function(x) x[col_names]) # Ensure consistent order/names

  # Use tryCatch for rbind in case of unexpected issues
  stations_df <- tryCatch(
    do.call("rbind", lapply(stations_list, data.frame, stringsAsFactors = FALSE)),
    error = function(e) {
      cli::cli_alert_danger("Failed to bind station data into data frame. Error: {e$message}")
      return(NULL)
    }
  )

  if (is.null(stations_df)) {
    cli::cli_process_failed(proc_id_proc)
    return(NULL)
  }

  # --- Convert to SF object (if requested) ---
  if (return_format == "sf") {
    # Check if coordinate columns exist
    if (!all(c("lon", "lat") %in% names(stations_df))) {
      cli::cli_process_failed(proc_id_proc, "Failed: Required 'lon' and/or 'lat' columns missing.")
      cli::cli_alert_info("Returning raw data frame instead.")
      stations_result <- stations_df # Fallback to dataframe
    } else {
      # Attempt numeric conversion safely
      stations_df$lon <- suppressWarnings(as.numeric(stations_df$lon))
      stations_df$lat <- suppressWarnings(as.numeric(stations_df$lat))

      # Check if conversion resulted in NAs where coordinates are needed
      na_coords <- is.na(stations_df$lon) | is.na(stations_df$lat)
      if (any(na_coords)) {
        warning(sum(na_coords), " stations had missing or non-numeric coordinates and could not be converted to sf points.", call. = FALSE)
        # Option 1: Filter out rows with NA coordinates
        # stations_df <- stations_df[!na_coords, ]
        # Option 2: Keep rows but geometry will be EMPTY (st_as_sf handles this)
      }

      # Proceed only if there are rows left to convert (or handle empty case)
      if (nrow(stations_df[!na_coords,]) > 0) {
        stations_result <- tryCatch(
          sf::st_as_sf(stations_df, coords = c("lon", "lat"), crs = crs, remove = FALSE, na.fail = FALSE),
          error = function(e){
            cli::cli_alert_danger("Failed to create sf object. Error: {e$message}")
            return(stations_df) # Fallback to dataframe on sf error
          }
        )
      } else if (nrow(stations_df) > 0) {
        cli::cli_alert_warning("All stations had missing coordinates. Returning data frame.")
        stations_result <- stations_df # All coords were NA
      } else {
        # Handle case where input df was empty after filtering (shouldn't happen with above logic)
        stations_result <- sf::st_sf(geometry = sf::st_sfc(crs = sf::st_crs(crs))) # Empty sf object
      }
    }
  } else {
    stations_result <- stations_df # Keep as data frame
  }
  cli::cli_process_done(proc_id_proc)

  # --- Write Cache ---
  if (!is.null(output_path)) {
    if (verbose) cli::cli_alert_info("Writing cache to {.file {output_path}} using format {.val {cache_format}}")
    proc_id_write <- cli::cli_process_start("Writing cache file")
    tryCatch({
      # Create directory if it doesn't exist
      dir.create(dirname(output_path), showWarnings = FALSE, recursive = TRUE)

      if (cache_format == "rds") {
        saveRDS(stations_result, file = output_path)
      } else { # cache_format == "csv"
        # Decide what to do with sf object for CSV
        if (inherits(stations_result, "sf")) {
          warning("Saving sf object to CSV loses spatial information. Consider cache_format = 'rds'.", call. = FALSE)
          # Option: write without geometry
          utils::write.csv(sf::st_drop_geometry(stations_result), file = output_path, row.names = FALSE)
          # Option: write with WKT geometry (requires sf >= 1.0)
          # sf::st_write(stations_result, output_path, layer_options = "GEOMETRY=AS_WKT", delete_dsn=TRUE)
        } else {
          utils::write.csv(stations_result, file = output_path, row.names = FALSE)
        }
      }
      cli::cli_process_done(proc_id_write)
    }, error = function(e) {
      cli::cli_process_failed(proc_id_write)
      cli::cli_alert_danger("Failed to write cache file: {e$message}")
      # Continue to return data even if caching fails
    })
  }

  # --- Return Result ---
  if (verbose) cli::cli_alert_success("Returning station data.")
  return(stations_result)
}
