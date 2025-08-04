# --------------------------------------------------------------------------
# Title: Temperaturen in der Nacht (Night Temperatures)
# Author: Robin Kohrs / Netzwerk Klimajournalismus
# Date: YYYY-MM-DD (R Script Conversion)
# Description: This script analyzes hourly temperature data to determine
#              night temperature trends, focusing on July.
#              It can download data for a single station (Wien Hohe Warte)
#              or all capital city stations in Austria.
#              Data for June, July, and August is downloaded in a single block
#              per year, then filtered for July for the final analysis.
#              Paths are defined using here::here() and davR::sys_make_path.
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# I. SCRIPT CONFIGURATION
# --------------------------------------------------------------------------
# Set to TRUE to download data for all capital city stations.
# Set to FALSE (default) to download data only for station 105 (Wien Hohe Warte).
download_all_stations <- TRUE # <<< USER PARAMETER

# --------------------------------------------------------------------------
# II. LOAD LIBRARIES
# --------------------------------------------------------------------------
# Note: Ensure these libraries are installed before running the script.
# You can install them using:
# install.packages(c("tidyverse", "glue", "davR", "here", "sf", "ggtext", "zoo", "lubridate", "data.table", "cli"))

library(tidyverse) # For data manipulation (dplyr, ggplot2, etc.) and pipes (%>%)
library(glue) # For easy string interpolation
library(davR) # For geosphere data access AND sys_make_path
library(here) # For robust path construction relative to project root
library(sf) # For spatial data operations (used for st_drop_geometry)
library(ggtext) # For markdown/HTML in ggplot2 text (e.g., titles)
library(zoo) # For rolling mean calculation (rollmean)
library(lubridate) # For date-time manipulation (month, year, hour, days_in_month)
library(data.table) # For fast file reading (fread)
library(cli) # For styled command-line messages

# --------------------------------------------------------------------------
# III. DEFINE PATHS AND GLOBAL VARIABLES
# --------------------------------------------------------------------------

# --- Define base paths using here::here() ---
# Assumes your R session's working directory is the project root,
# or that 'here' can correctly identify the project root.

# Path for raw hourly data. davR::sys_make_path creates the directory if it doesn't exist.
# Example: [ProjectRoot]/data_raw/tropennächte_studie/stationenStundenDaten/
data_raw_base_for_script <- here::here(sys_get_script_dir(), "data_raw")
data_raw_path_hourly_data <- davR::sys_make_path(file.path(
  data_raw_base_for_script,
  "stationenStundenDaten_raw/single"
))
data_raw_path_hourly_data_chunks <- davR::sys_make_path(file.path(
  data_raw_base_for_script,
  "stationenStundenDaten_raw/chunks"
))
data_raw_path_hourly_data_processed <- davR::sys_make_path(file.path(
  data_raw_base_for_script,
  "processed/tropennächte/dw"
))
data_raw_path_hourly_data_invalid <- davR::sys_make_path(file.path(
  data_raw_base_for_script,
  "processed/tropennächte/invalid"
))


# Path for saving output images
# Example: [ProjectRoot]/images_r_output/
output_images_path <- davR::sys_make_path(file.path(
  sys_get_script_dir(),
  "images/tropennächte"
))


# Data download parameters
resource_id <- "klima-v2-1h"
start_year <- 1940 # Earliest year to attempt download for
end_year <- 2025 # Latest year to attempt download for (adjust if needed)

# Target month for analysis
month_start <- 6
month_end <- 8

# Night hours definition
night_hour_start <- 18
night_hour_end <- 6

# Helper function to split a vector into chunks of a specific size
split_into_chunks <- function(vec, chunk_size) {
  num_elements <- length(vec)
  num_chunks <- ceiling(num_elements / chunk_size)
  split(vec, cut(seq_along(vec), num_chunks, labels = FALSE))
}

# --------------------------------------------------------------------------
# IV. DATA DOWNLOAD (June-August block download per year)
# --------------------------------------------------------------------------
cli::cli_alert_info("Starting data download process...")
stations <- davR::geosphere_get_stations() %>%
  filter(is_active) %>%
  filter(
    !id %in%
      c(
        8807,
        11200,
        11306,
        11401,
        11602,
        12016,
        12352,
        14105,
        14310,
        14602,
        14621,
        14834,
        15300,
        17003
      )
  )
all_station_ids_available <- stations$id # Use a different name to avoid confusion

# Determine which station IDs to process
if (!download_all_stations) {
  station_ids_to_process <- c(105) # wien hohe warte
} else {
  station_ids_to_process <- all_station_ids_available
}

# Define chunk size
STATION_CHUNK_SIZE <- 40 # << NEW: Number of station IDs per download request

# Split station_ids_to_process into chunks
station_id_chunks <- split_into_chunks(
  station_ids_to_process,
  STATION_CHUNK_SIZE
)
cli::cli_alert_info(glue::glue(
  "Processing {length(station_ids_to_process)} station(s) in {length(station_id_chunks)} chunk(s) of up to {STATION_CHUNK_SIZE} stations each."
))


# Loop through years first, then through chunks of stations
for (current_year in start_year:end_year) {
  start_date_period <- glue::glue("{current_year}-{month_start}-01")
  # Correctly get the last day of the month_end for the current_year
  end_date_for_month <- ymd(glue::glue("{current_year}-{month_end}-01")) +
    months(1) -
    days(1)
  end_date_period <- format(end_date_for_month, "%Y-%m-%d")

  for (chunk_index in seq_along(station_id_chunks)) {
    current_station_id_chunk <- station_id_chunks[[chunk_index]]
    # Create a compact representation of station IDs in the chunk for filenames if needed
    chunk_label <- paste0(
      "chunk",
      chunk_index,
      "_stations_",
      current_station_id_chunk[1],
      "-",
      current_station_id_chunk[length(current_station_id_chunk)]
    )

    # MODIFIED Filename: Now includes year and chunk identifier, not individual station
    filename <- glue::glue(
      "data__{chunk_label}__ys{current_year}__ye{current_year}__ms{month_start}__me{month_end}__hourly_data.csv"
    )
    # Store these multi-station files in a general directory, not per-station_id
    output_filepath <- sys_make_path(file.path(
      data_raw_path_hourly_data_chunks,
      current_year,
      filename
    ))

    if (file.exists(output_filepath)) {
      cli::cli_alert_info(paste0(
        "File already exists, skipping download: ",
        filename
      ))
    } else {
      cli::cli_alert_info(glue::glue(
        "Attempting to download data for: Year {current_year}, Period June-August, Station Chunk {chunk_index} ({length(current_station_id_chunk)} stations)"
      ))
      download_attempt <- tryCatch(
        {
          data <- davR::geosphere_get_data(
            resource_id = resource_id,
            parameters = c("tl"),
            start = start_date_period,
            end = end_date_period,
            station_ids = current_station_id_chunk, # <<< PASS THE CHUNK OF IDs
            type = "station",
            mode = "historical",
            output_file = output_filepath,
            timeout_seconds = 40 # Increase timeout for potentially larger requests
          ) %>%
            read_csv()

          # split into stations
          per_station <- data %>% split(.$station)

          # for each station
          iwalk(per_station, function(s, station_id) {
            station_name_real <- stations %>%
              filter(id == as.numeric(station_id)) %>%
              pull(name)

            station_clean_name <- stations %>%
              filter(id == as.numeric(station_id)) %>%
              pull(name) %>%
              janitor::make_clean_names()

            filename <- glue::glue(
              "{station_clean_name}__id{station_id}__ys{current_year}__ye{current_year}__ms{month_start}__me{month_end}__hourly_data.csv"
            )
            output_filepath <- sys_make_path(file.path(
              data_raw_path_hourly_data,
              station_id,
              filename
            ))
            write_csv(s, output_filepath)
          })
          TRUE
        },
        error = function(e) {
          cli::cli_warn(glue::glue(
            "Failed downloading data for {current_year} (June-August) for station chunk {chunk_index} (IDs: {paste(current_station_id_chunk, collapse=', ')}): {conditionMessage(e)}"
          ))
          return(NULL)
        }
      )
      if (isTRUE(download_attempt)) {
        cli::cli_alert_success(glue::glue(
          "Successfully downloaded and saved: {filename}"
        ))
      }
    }
  }
}

# count number of files per dir  ------------------------------------------------------
ls <- fs::dir_ls(data_raw_path_hourly_data_chunks) %>%
  map(function(d) {
    y <- basename(d)
    l <- length(fs::dir_ls(d))
    return(data.frame(y = y, l = l))
  }) %>%
  bind_rows() %>%
  filter(l != 12)


# data for each station  ------------------------------------------------------
walk(seq_along(stations$id), function(i) {
  # cat(glue("{i}/{length(stations$id)}\r"))
  print(i)

  station_id <- stations$id[[i]]
  ##### get the name of the station
  station_name_real <- stations %>%
    filter(id == station_id) %>%
    pull(name)

  station_clean_name <- stations %>%
    filter(id == station_id) %>%
    pull(name) %>%
    janitor::make_clean_names()

  data_files_paths <- list.files(
    path = file.path(data_raw_path_hourly_data, station_id),
    pattern = glue("id{station_id}_.*\\.csv"),
    full.names = TRUE
  )

  if (length(data_files_paths) == 0) {
    cli::cli_abort(
      glue::glue(
        "No files found"
      )
    )
  }

  all_downloaded_data <- purrr::map_dfr(data_files_paths, function(filepath) {
    tryCatch(
      {
        # suppressMessages(read_csv(filepath))
        data.table::fread(filepath) %>% as.data.frame()
      },
      error = function(e) {
        cli::cli_warn(glue::glue(
          "Error reading file {filepath}: {conditionMessage(e)}"
        ))
        return(NULL)
      }
    )
  }) %>%
    mutate(time = lubridate::with_tz(time, "Europe/Vienna"))

  # basic checks  ------------------------------------------------------
  if (sum(!is.na(all_downloaded_data$tl)) == 0) {
    return()
  }
  unique_months <- all_downloaded_data %>%
    filter(!is.na(tl)) %>%
    mutate(month = lubridate::month(time)) %>%
    distinct(month) %>%
    pull(month)

  if (length(unique_months) < 3) {
    return()
  }

  # calculate means for each month  --------------------------------------------
  mean_data <- all_downloaded_data %>%
    mutate(
      year = year(time),
      month = month(time),
      hour = hour(time)
    ) %>%
    filter(hour >= night_hour_start | hour < night_hour_end) %>%
    # 3. Group by year and month
    group_by(year, month) %>%
    # 4. Calculate the mean nightly temperature, ignoring NAs
    summarise(
      mean_nightly_tl = mean(tl, na.rm = TRUE),
      valid_hours = sum(!is.na(tl)),
      nonvalid_hours = sum(is.na(tl)),
      share_invalid = nonvalid_hours / (valid_hours + nonvalid_hours),
      .groups = "drop"
    ) %>%
    filter(!is.nan(mean_nightly_tl)) %>%
    # 5. Order the results (optional, but nice)
    arrange(year, month)

  # check for each year if the share of non valid data is higher than 5 percent
  df_invalid_high_share <- mean_data %>% filter(share_invalid >= 0.05)
  if (nrow(df_invalid_high_share) > 0) {
    cli::cli_warn(
      glue(
        "For: {station_clean_name} there are years with a invalid data share of larger than 5 % - n={nrow(df_invalid_high_share)}"
      )
    )
    filename <- glue("id{station_id}_HIGH_SHARE_NAs.csv")
    op_invalid <- file.path(data_raw_path_hourly_data_invalid, filename)
    write_csv(df_invalid_high_share, op_invalid)
  }

  # yet another check  ------------------------------------------------------
  if (nrow(mean_data) == 0) {
    return()
  }

  #  prepare for datawrapper format  ------------------------------------------------------
  data_dw <- mean_data %>%
    select(year, month, mean_nightly_tl, share_no_data = share_invalid) %>%
    mutate(
      month = lubridate::month(month, label = T)
    ) %>%
    pivot_wider(
      names_from = month,
      values_from = mean_nightly_tl
    ) %>%
    mutate(
      across(
        .cols = c(Jun, Jul, Aug), # Columns to apply the function to
        .fns = ~ rollapply(
          .x, # .x refers to the current column's data
          width = 5,
          FUN = mean,
          align = "right",
          fill = NA,
          na.rm = TRUE
        ),
        .names = "{.col}_5yr_avg" # Naming convention for the new columns
      )
    ) %>%
    mutate(
      station_id = station_id,
      .before = 1,
    ) %>%
    mutate(
      station_name = station_name_real,
      .before = 1
    )

  # write out  ------------------------------------------------------
  min_start_year <- min(data_dw$year)
  max_start_year <- max(data_dw$year)
  filename_dw <- glue::glue(
    "{station_clean_name}__id{station_id}__ys{min_start_year}__ye{max_start_year}__ms{month_start}__me{month_end}__meanNightTempPerMonth.csv"
  )
  op_dw <- file.path(data_raw_path_hourly_data_processed, filename_dw)
  write_csv(data_dw, op_dw)
})
