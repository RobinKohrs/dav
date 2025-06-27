#' Incrementally Archive Geosphere Data (Simple Batched Version)
#'
#' @description
#' Downloads data from Geosphere and saves it to a local archive by batching
#' stations and time periods to minimize API calls. Respects API rate limits
#' (5 requests/second, 240/hour) and request size limits (1M values for CSV).
#'
#' @param resource_id The dataset ID to archive (e.g., "klima-v2-10min").
#' @param params Vector of parameters to download (e.g., c("tl", "ts", "tlmax", "tsmax")).
#' @param archive_dir The root directory for the archive.
#' @param start_date Optional. The start date for the download (YYYY-MM-DD). If `NULL`,
#'   the function uses each station's specific `valid_from` date.
#' @param end_date Optional. The end date for the download (YYYY-MM-DD). Defaults to
#'   the current system date.
#' @param station_ids Optional vector of station IDs. If `NULL`, all stations are used.
#' @param station_batch_size Number of stations to query together (default: calculated based on rate limits).
#' @param time_batch_size Time period to query at once: "day", "week", "month", "year" (default: "month").
#' @param api_delay_secs Seconds to wait between each API call (default: 0.2 to respect 5 req/sec limit).
#' @param api_url Base URL for the Geosphere API.
#' @param print_url If `TRUE`, prints the full URL that will be requested for each API call.
#'
#' @return Invisibly returns a list containing counts of downloaded, skipped,
#'   and failed files.
#' @export
#' @importFrom cli cli_h1 cli_alert_info cli_alert_danger cli_alert_success cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom lubridate ceiling_date days months years
#' @importFrom glue glue
#' @importFrom digest digest

geosphere_archive_station_data <- function(
    resource_id, 
    params = c("tl", "ts", "tlmax", "tsmax"), 
    archive_dir = "geosphere_station_archive", 
    start_date = NULL, 
    end_date = NULL, 
    station_ids = NULL, 
    station_batch_size = NULL,
    time_batch_size = "month",
    api_delay_secs = 0.2, 
    api_url = "https://dataset.api.hub.geosphere.at",
    print_url = FALSE) {

  cli::cli_h1("Starting Geosphere Archiver (Rate-Limited Mode)")

  # --- 1. PREPARATION AND METADATA FETCHING ---
  if (is.null(end_date)) end_date <- Sys.Date() else end_date <- as.Date(end_date)

  # Add initial delay to ensure we're not hitting rate limits from previous calls
  cli::cli_alert_info("Initializing with rate limit delay...")
  Sys.sleep(1)  # 1 second initial delay

  metadata_url <- file.path(api_url, "v1", "station", "historical", resource_id, "metadata")
  cli::cli_alert_info("Fetching station metadata...")
  
  # Add retry logic for metadata fetching with rate limiting
  all_stations_df <- NULL
  for (attempt in 1:5) {  # Increase attempts to 5
    cli::cli_alert_info(paste0("Metadata fetch attempt ", attempt, "/5"))
    
    # Add delay before metadata fetch to respect rate limits
    if (attempt > 1) {
      wait_time <- 30 * (attempt - 1)  # 30s, then 60s, then 90s, then 120s
      cli::cli_alert_info(paste0("Waiting ", wait_time, " seconds before retry..."))
      Sys.sleep(wait_time)
    }
    
    # Use geosphere_get_stations with retry logic
    all_stations_df <- geosphere_get_stations(metadata_url = metadata_url, return_format = "dataframe")
    
    if (!is.null(all_stations_df) && is.data.frame(all_stations_df) && nrow(all_stations_df) > 0) {
      cli::cli_alert_success("Metadata fetch successful!")
      break
    } else {
      if (attempt < 5) {
        cli::cli_alert_warning("Metadata fetch failed, will retry...")
      } else {
        cli::cli_alert_danger("All metadata fetch attempts failed.")
      }
    }
  }

  if (is.null(all_stations_df) || !is.data.frame(all_stations_df) || nrow(all_stations_df) == 0) {
    cli::cli_alert_danger("Could not retrieve station metadata or metadata is empty. Aborting.")
    return(invisible(NULL))
  }
  if (!all(c("id", "valid_from") %in% names(all_stations_df))) {
    cli::cli_alert_danger("Metadata missing 'id' or 'valid_from' columns. Aborting.")
    return(invisible(NULL))
  }

  target_stations_df <- if (is.null(station_ids)) all_stations_df else all_stations_df[all_stations_df$id %in% station_ids, ]
  if (nrow(target_stations_df) == 0) {
    cli::cli_alert_danger("No target stations found. Aborting.")
    return(invisible(NULL))
  }
  cli::cli_alert_success(paste0("Found ", nrow(target_stations_df), " target stations."))

  # --- 2. OPTIMIZE BATCH SIZES BASED ON RATE LIMITS ---
  # Calculate optimal station batch size based on request size limits
  if (is.null(station_batch_size)) {
    # Estimate time steps per batch based on time_batch_size
    time_steps_per_batch <- switch(time_batch_size,
      "day" = 24 * 60 / 10,      # 10-min data: 144 steps/day
      "week" = 7 * 24 * 60 / 10, # 10-min data: 1008 steps/week  
      "month" = 30 * 24 * 60 / 10, # 10-min data: ~4320 steps/month
      "year" = 365 * 24 * 60 / 10  # 10-min data: ~52560 steps/year
    )
    
    # Calculate max stations per batch: 1M values / (params * time_steps)
    max_values_per_request <- 1000000
    station_batch_size <- max(1, floor(max_values_per_request / (length(params) * time_steps_per_batch)))
    
    cli::cli_alert_info(paste0("Calculated optimal station batch size: ", station_batch_size, 
                               " (", length(params), " params × ~", round(time_steps_per_batch), " time steps)"))
  }

  # Ensure we don't exceed rate limits
  if (api_delay_secs < 0.2) {
    cli::cli_alert_warning("API delay increased to 0.2 seconds to respect 5 requests/second limit")
    api_delay_secs <- 0.2
  }

  # --- 3. BATCHED PROCESSING ---
  resource_archive_path <- file.path(archive_dir, resource_id)
  if (!dir.exists(resource_archive_path)) dir.create(resource_archive_path, recursive = TRUE)

  # Create batches folder in main directory
  batches_dir <- file.path(archive_dir, "batches")
  if (!dir.exists(batches_dir)) dir.create(batches_dir, recursive = TRUE)
  cli::cli_alert_info(paste0("Created batches directory: ", batches_dir))

  # Create time batches
  time_batches <- create_time_batches(start_date, end_date, time_batch_size, target_stations_df)
  
  # Create station batches
  station_batches <- split(target_stations_df$id, ceiling(seq_along(target_stations_df$id) / station_batch_size))
  
  total_batches <- length(time_batches) * length(station_batches)
  cli::cli_alert_info(paste0("Processing ", total_batches, " batches (", length(time_batches), " time periods × ", length(station_batches), " station groups)"))
  cli::cli_alert_info(paste0("Rate limit: 5 requests/second, 240 requests/hour"))
  cli::cli_alert_info(paste0("Estimated time: ~", round(total_batches * api_delay_secs / 60, 1), " minutes"))

  stats <- list(downloaded = 0, skipped = 0, failed = 0, checked = 0, rate_limited = 0)

  # --- 4. CREATE ALL BATCHES ---
  cli::cli_alert_info("Creating batch list...")
  all_batches <- list()
  batch_counter <- 0
  
  for (time_batch in time_batches) {
    for (station_batch in station_batches) {
      # Create batch filename with hash of station IDs
      station_hash <- substr(digest::digest(paste(sort(station_batch), collapse = "_"), algo = "md5"), 1, 8)
      batch_filename <- paste0("batch_", time_batch$start_str, "_to_", time_batch$end_str, "_", station_hash, ".csv")
      batch_path <- file.path(batches_dir, batch_filename)
      
      # Check if individual station files already exist
      # We only check individual files since batch files are deleted after processing
      all_station_files_exist <- TRUE
      for (station_id in station_batch) {
        # Create station subdirectory path
        station_dir <- file.path(resource_archive_path, station_id)
        
        # Check for files that might exist for this time period
        # We need to check multiple possible dates since the actual data might start on different days
        # within the time period (e.g., batch covers 1992-01-01 to 1992-01-31, but data starts on 1992-01-02)
        potential_files_exist <- FALSE
        
        # Check for files starting from batch start date up to batch end date
        # Ensure we have proper Date objects
        batch_start_date <- as.Date(time_batch$start)
        batch_end_date <- as.Date(time_batch$end)
        
        # Check if we have valid dates before proceeding
        if (is.na(batch_start_date) || is.na(batch_end_date)) {
          cli::cli_alert_warning(paste0("Invalid dates for batch: start=", time_batch$start, ", end=", time_batch$end))
          all_station_files_exist <- FALSE
          break
        }
        
        for (check_date in seq(batch_start_date, batch_end_date, by = "day")) {
          # Convert numeric date back to Date object if needed
          if (is.numeric(check_date)) {
            check_date <- as.Date(check_date, origin = "1970-01-01")
          }
          
          # Try to format the date with error handling
          tryCatch({
            formatted_date <- format(check_date, "%Y-%m-%d")
            station_filename <- paste0(resource_id, "_", station_id, "_", formatted_date, ".csv")
            station_path <- file.path(station_dir, station_filename)
            if (file.exists(station_path)) {
              potential_files_exist <- TRUE
              break
            }
          }, error = function(e) {
            cli::cli_alert_danger(paste0("Error formatting date ", check_date, ": ", e$message))
            # Continue with next date instead of crashing
          })
        }
        
        if (!potential_files_exist) {
          all_station_files_exist <- FALSE
          break
        }
      }
      
      # Skip if all individual station files exist
      if (all_station_files_exist) {
        stats$skipped <- stats$skipped + 1
        next
      }
      
      # Only increment counter when we actually create a batch
      batch_counter <- batch_counter + 1
      
      # Add batch to processing list
      all_batches[[batch_counter]] <- list(
        batch_id = batch_counter,
        time_batch = time_batch,
        station_batch = station_batch,
        batch_path = batch_path,
        resource_id = resource_id,
        params = params,
        resource_archive_path = resource_archive_path,
        time_batch_size = time_batch_size,
        api_url = api_url,
        print_url = print_url,
        api_delay_secs = api_delay_secs
      )
    }
  }
  
  total_batches <- length(all_batches)
  cli::cli_alert_info(paste0("Created ", total_batches, " batches for processing"))
  
  if (total_batches == 0) {
    cli::cli_alert_success("All data already exists. Nothing to download.")
    return(invisible(stats))
  }
  
  # --- 5. SEQUENTIAL PROCESSING ---
  cli::cli_alert_info("Starting sequential processing")
  
  for (batch in all_batches) {
    stats$checked <- stats$checked + 1
    
    # Simple retry logic: try up to 3 times with exponential backoff for rate limits
    success <- FALSE
    for (attempt in 1:3) {
      cli::cli_alert_info(paste0("Batch ", stats$checked, "/", total_batches, " - Attempt ", attempt, "/3"))
      
      result <- geosphere_get_data(
        resource_id = batch$resource_id,
        parameters = batch$params,
        station_ids = batch$station_batch,
        start = batch$time_batch$api_start,
        end = batch$time_batch$api_end,
        output_format = "csv",
        return_format = "file",
        type = "station",
        mode = "historical",
        output_file = batch$batch_path,
        verbose = FALSE,
        print_url = batch$print_url,
        api_url = batch$api_url,
        timeout_seconds = 30
      )
      
      # Handle new return format with rate limit info
      if (is.list(result) && !is.null(result$result)) {
        success <- TRUE
        stats$downloaded <- stats$downloaded + 1
        cli::cli_alert_success("Download successful!")
        
        # Print rate limit info
        if (!is.null(result$rate_limit_info)) {
          remaining_second <- as.numeric(result$rate_limit_info$remaining_second) %||% "unknown"
          remaining_hour <- as.numeric(result$rate_limit_info$remaining_hour) %||% "unknown"
          cli::cli_alert_info(glue::glue("Rate limit: {remaining_second} req/sec, {remaining_hour} req/hour remaining"))
        }
        
        # Split batch file into individual station files
        split_batch_file(result$result, batch$resource_archive_path, batch$resource_id, batch$time_batch_size)
        break
      } else {
        # Check if this was a rate limit error (429)
        if (attempt < 3) {
          # Check if we have rate limit info for intelligent waiting
          if (is.list(result) && !is.null(result$rate_limit_info)) {
            reset_seconds <- as.numeric(result$rate_limit_info$reset_seconds) %||% 3600
            wait_time <- min(reset_seconds + 10, 300)  # Wait for reset + 10s, max 5 minutes
            cli::cli_alert_warning(paste0("Rate limit exceeded. Waiting ", round(wait_time/60, 1), " minutes for reset..."))
            stats$rate_limited <- stats$rate_limited + 1
          } else {
            # For other errors, use exponential backoff
            wait_time <- 5 * (2^(attempt - 1))  # 5s, then 10s
            cli::cli_alert_warning(paste0("Download failed. Waiting ", wait_time, " seconds before retry..."))
          }
          Sys.sleep(wait_time)
        } else {
          cli::cli_alert_danger("All 3 attempts failed for this batch.")
          stats$failed <- stats$failed + 1
        }
      }
    }
    
    # Respect rate limits between requests
    Sys.sleep(batch$api_delay_secs)
  }

  cli::cli_alert_success("Archiving process complete.")
  cli::cli_alert_info(paste0(stats$downloaded, " batches downloaded, ", stats$skipped, " batches skipped, ", stats$failed, " batches failed."))
  if (stats$rate_limited > 0) {
    cli::cli_alert_info(paste0(stats$rate_limited, " rate limit events handled."))
  }
  cli::cli_alert_info(paste0("Data organized in: ", archive_dir, "/", resource_id, "/<station_id>/"))

  invisible(stats)
}

# Helper function to create time batches
create_time_batches <- function(start_date, end_date, time_batch_size, stations_df) {
  batches <- list()

  if (time_batch_size == "day") {
    by_period <- "day"
  } else if (time_batch_size == "week") {
    by_period <- "week"
  } else if (time_batch_size == "month") {
    by_period <- "month"
  } else if (time_batch_size == "year") {
    by_period <- "year"
  } else {
    stop("Invalid time_batch_size. Must be 'day', 'week', 'month', or 'year'")
  }

  # Create sequence of dates
  if (is.null(start_date)) {
    # Use earliest valid_from date from stations, with better error handling
    valid_dates <- stations_df$valid_from[!is.na(stations_df$valid_from)]
    cli::cli_alert_info(paste0("Found ", length(valid_dates), " valid dates out of ", length(stations_df$valid_from), " total dates"))

    if (length(valid_dates) > 0) {
      # Ensure we get a proper Date object, not POSIXct
      earliest_date <- as.Date(min(valid_dates))
      cli::cli_alert_info(paste0("Using earliest station date: ", earliest_date))
    } else {
      # Fallback: use 1 year ago from end_date
      earliest_date <- end_date - 365
      cli::cli_alert_warning("No valid 'valid_from' dates found in station metadata. Using 1 year ago as start date.")
    }
  } else {
    earliest_date <- as.Date(start_date)
    cli::cli_alert_info(paste0("Using provided start date: ", earliest_date))
  }

  # Ensure end_date is also a Date object
  end_date <- as.Date(end_date)

  # Ensure we have valid dates
  if (is.na(earliest_date) || is.na(end_date)) {
    cli::cli_alert_danger(paste0("earliest_date: ", earliest_date, ", end_date: ", end_date))
    stop("Invalid start or end date. Please check your date parameters.")
  }

  # Ensure earliest_date is not after end_date
  if (earliest_date > end_date) {
    earliest_date <- end_date - 30  # fallback to 30 days ago
    cli::cli_alert_warning("Start date is after end date. Using 30 days ago as start date.")
  }

  cli::cli_alert_info(paste0("Creating date sequence from ", earliest_date, " to ", end_date, " by ", by_period))
  date_sequence <- seq(from = earliest_date, to = end_date, by = by_period)

  for (i in 1:length(date_sequence)) {
    batch_start <- date_sequence[i]
    # Ensure batch_start is a Date object
    batch_start <- as.Date(batch_start, origin = "1970-01-01")

    if (i == length(date_sequence)) {
      batch_end <- end_date
    } else {
      batch_end <- date_sequence[i + 1] - 1
      # Ensure batch_end is a Date object
      batch_end <- as.Date(batch_end, origin = "1970-01-01")
    }

    batches[[i]] <- list(
      start = batch_start,
      end = batch_end,
      api_start = format(batch_start, "%Y-%m-%dT00:00:00"),
      api_end = format(batch_end, "%Y-%m-%dT23:59:59"),
      start_str = format(batch_start, "%Y%m%d"),
      end_str = format(batch_end, "%Y%m%d")
    )
  }

  return(batches)
}

# Helper function to split batch file into individual station files
split_batch_file <- function(batch_path, archive_path, resource_id, time_batch_size) {
  tryCatch({
    # Read the batch file
    batch_data <- read.csv(batch_path, stringsAsFactors = FALSE)

    if (nrow(batch_data) == 0) return()

    # Check if there's a station column (common names)
    station_col <- NULL
    for (col_name in c("station_id", "station", "id", "stationid")) {
      if (col_name %in% names(batch_data)) {
        station_col <- col_name
        break
      }
    }

    if (is.null(station_col)) {
      cli::cli_alert_warning("Could not identify station column in batch file")
      return()
    }

    # Split by station
    stations <- unique(batch_data[[station_col]])

    for (station_id in stations) {
      station_data <- batch_data[batch_data[[station_col]] == station_id, ]

      if (nrow(station_data) == 0) next

      # Create station subdirectory
      station_dir <- file.path(archive_path, station_id)
      if (!dir.exists(station_dir)) {
        dir.create(station_dir, recursive = TRUE)
      }

      # Create individual station file
      station_filename <- paste0(resource_id, "_", station_id, "_", format(as.Date(station_data$time[1]), "%Y-%m-%d"), ".csv")
      station_path <- file.path(station_dir, station_filename)

      # Only write if file doesn't exist or if we have more data
      if (!file.exists(station_path) || file.size(station_path) < nrow(station_data) * 100) {
        write.csv(station_data, station_path, row.names = FALSE)
      }
    }

    # Remove the batch file to save space
    file.remove(batch_path)

  }, error = function(e) {
    cli::cli_alert_warning(paste0("Error splitting batch file: ", e$message))
  })
}

# Test function to compare manual vs function execution
test_geosphere_call <- function() {
  cli::cli_h1("Testing Geosphere API Call")
  
  # Test parameters
  test_params <- c("tl", "ts", "tlmax", "tsmax")
  test_stations <- c("31", "32", "36")
  test_start <- "2024-01-01T00:00:00"
  test_end <- "2024-01-31T23:59:59"
  
  cli::cli_alert_info("Test parameters:")
  cli::cli_alert_info(paste0("  Parameters: ", paste(test_params, collapse = ", ")))
  cli::cli_alert_info(paste0("  Parameters class: ", class(test_params)[1]))
  cli::cli_alert_info(paste0("  Stations: ", paste(test_stations, collapse = ", ")))
  cli::cli_alert_info(paste0("  Start: ", test_start))
  cli::cli_alert_info(paste0("  End: ", test_end))
  
  # Test the API call
  result <- geosphere_get_data(
    resource_id = "klima-v2-10min",
    parameters = test_params,
    station_ids = test_stations,
    start = test_start,
    end = test_end,
    output_format = "csv",
    return_format = "dataframe",
    type = "station",
    mode = "historical",
    verbose = TRUE,
    timeout_seconds = 30
  )
  
  if (!is.null(result)) {
    cli::cli_alert_success("Test call successful!")
    cli::cli_alert_info(paste0("Returned data with ", nrow(result), " rows"))
  } else {
    cli::cli_alert_danger("Test call failed!")
  }
  
  return(result)
}
