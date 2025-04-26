# -------------------------------------------------------------------------
# Set options (can be placed in a setup/init script)
# -------------------------------------------------------------------------
options(timeout = 999999)

# -------------------------------------------------------------------------
# Get the latest file from a remote server
# -------------------------------------------------------------------------

get_latest_file <- function(host = c("nwp", "nowcast", "ensemble"), base_url = "ftp://eaftp.zamg.ac.at/") {
  host <- match.arg(host)
  host_url <- paste0(base_url, host, "/")
  print(host_url)

  current_files <- RCurl::getURL(
    url = host_url,
    verbose = TRUE,
    ftp.use.epsv = TRUE,
    dirlistonly = TRUE
  )

  files_clean <- strsplit(current_files, "\n")[[1]]
  latest_file <- sort(files_clean)[length(files_clean)]

  return(list(
    name = latest_file,
    remote_path = file.path(host_url, latest_file)
  ))
}

# -------------------------------------------------------------------------
# Read and extract raster data for a specific point
# -------------------------------------------------------------------------

get_raster_data_at_point <- function(local_path,
                                     subdatasets = "T",
                                     x, y,
                                     level = NULL,
                                     timezone = "Europe/Paris") {
  data <- terra::rast(local_path, subds = subdatasets)

  # Select specific level if requested
  if (!is.null(level)) {
    level_pattern <- glue::glue("T_level={level}")
    level_indices <- grep(level_pattern, names(data))
    data <- data[[level_indices]]
  }

  # Get times and extract data
  times <- terra::time(data)
  times_converted <- lubridate::with_tz(times, timezone)

  extracted <- terra::extract(data, data.frame(x = x, y = y)) |>
    dplyr::select(-ID)

  df <- data.frame(
    value = purrr::map_dbl(unname(extracted), 1),
    time = times_converted
  )

  return(df)
}

# -------------------------------------------------------------------------
# Wrapper: Download and process the latest data
# -------------------------------------------------------------------------

#' @title Weather Forecast
#' @description Get weather predictions for Austria/Alps
#' @param host Character. The data source to query. Must be one of:
#' \describe{
#'   \item{\code{"nwp"}}{Numerical Weather Prediction (NWP) model outputs. These are high-resolution forecasts for the extended Alpine region on a 2.5 km grid, updated every 3 hours with a forecast horizon of 60 hours. For more information, visit \url{https://data.hub.geosphere.at/dataset/nwp-v1-1h-2500m}.}
#'   \item{\code{"nowcast"}}{Short-term forecasts using real-time observations and radar data, useful for rapid updates. For more information, visit \url{https://data.hub.geosphere.at/dataset/nowcast-v1-15min-1km}.}
#'   \item{\code{"ensemble"}}{The C-LAEF (Convection-permitting Limited-Area Ensemble Forecasting) system provides weather forecasts for the extended Alpine region on a 2.5 km grid. It is updated twice daily with a forecast horizon of 60 hours. The dataset includes the 10th, 50th, and 90th percentiles from 17 model runs (16 ensemble members + 1 control run), allowing for uncertainty estimation in the forecasts. For more information, visit \url{https://data.hub.geosphere.at/dataset/ensemble-v1-1h-2500m}.}
#' }
#' @param x the coordinates of the point to get the prediction for
#' @param y the coordinates of the point to get the prediction for
#' @param level the level of the prediction to get
#' @param subdatasets the subdatasets to get
#' @param download_dir the directory to download the data to
#' @param timezone the timezone of the prediction
#' @return a data.frame with the prediction
#' @export
#' @export
geosphere_get_prediction <- function(host,
                                     x,
                                     y,
                                     level = NULL,
                                     subdatasets = NULL,
                                     download_dir = "data_raw",
                                     timezone = "Europe/Paris") {
  # get the lastest file of the prediction
  latest_file <- get_latest_file(host)


  # download the file to local
  local_path <- file.path(download_dir, host, latest_file$name)
  if (!file.exists(local_path)) {
    dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
    download.file(latest_file$remote_path, destfile = local_path)
  } else {
    message("File already exists: ", local_path)
  }

  # prompt for the subdatasets
  if (is.null(subdatasets)) {
    subdatasets <- gdal_info_table(local_path)
  }

  data <- get_raster_data_at_point(local_path,
    subdatasets = subdatasets,
    x = x, y = y,
    level = level,
    timezone = timezone
  )

  return(data)
}
