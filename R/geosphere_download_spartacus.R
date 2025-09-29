#' @title Download SPARTACUS Gridded Climate Data
#' @description Downloads SPARTACUS v2 gridded climate data from Geosphere Austria
#'              for a specified resolution, year, variable type, and other relevant parameters.
#'              **Note:** The internal schemas (resource IDs, filenames) must be correctly
#'              defined for this function to work. Verify these against the Geosphere Data Hub.
#'
#' @param dest_dir Directory to save the file.
#' @param resolution Character string specifying the temporal resolution.
#'                   Allowed values: "daily", "monthly", "seasonal", "yearly".
#' @param year The year of the data (e.g., 2020).
#' @param variable_type The climate variable type (e.g., "TX", "TM", "RR", "SA").
#'                      Allowed values depend on the chosen resolution and schema.
#' @param month Integer, the month (1-12). Only used if `resolution = "monthly"`
#'              AND if the monthly data is stored in separate files per month (schema-dependent).
#'              Current example schema for monthly assumes one file per year.
#' @param season_code Character string for the season. Only used if `resolution = "seasonal"`.
#'                    Example: "DJF", "MAM", "JJA", "SON". (Schema-dependent).
#' @param base_data_url Base URL for Geosphere data.
#' @param user_agent Custom User-Agent.
#' @param overwrite Logical, whether to overwrite existing files.
#' @param verbose Logical, for verbose output.
#' @param timeout_seconds Request timeout.
#'
#' @return Path to the downloaded file or `NA_character_` on failure.
#' @export
#' @examples
#' \dontrun{
#' # --- IMPORTANT: Ensure GEOSPHERE_DATA_SCHEMAS is correctly defined and loaded ---
#' # --- The following examples depend on your schema definitions (especially filename templates) ---
#'
#' temp_dir <- tempfile("spartacus_dl_")
#' dir.create(temp_dir)
#'
#' # Example: Download Daily Max Temperature for 2020
#' daily_tx_2020 <- download_geosphere_spartacus(
#'   dest_dir = temp_dir,
#'   resolution = "daily",
#'   year = 2020,
#'   variable_type = "TX"
#' )
#' if (!is.na(daily_tx_2020)) print(paste("Downloaded:", daily_tx_2020))
#'
#' # Example: Download Monthly Mean Temperature for 2019
#' monthly_tm_2019 <- download_geosphere_spartacus(
#'   dest_dir = temp_dir,
#'   resolution = "monthly",
#'   year = 2019,
#'   variable_type = "TM"
#' )
#' if (!is.na(monthly_tm_2019)) print(paste("Downloaded:", monthly_tm_2019))
#'
#' # Example: Download Seasonal Precipitation for 2018, Summer (JJA)
#' seasonal_rr_2018_jja <- download_geosphere_spartacus(
#'   dest_dir = temp_dir,
#'   resolution = "seasonal",
#'   year = 2018,
#'   variable_type = "RR",
#'   season_code = "JJA"
#' )
#' if (!is.na(seasonal_rr_2018_jja)) print(paste("Downloaded:", seasonal_rr_2018_jja))
#'
#' unlink(temp_dir, recursive = TRUE)
#' }
geosphere_download_spartacus = function(
    dest_dir,
    resolution,
    year,
    variable_type,
    month = NULL,
    season_code = NULL,
    base_data_url = "https://public.hub.geosphere.at/datahub/resources/",
    user_agent = NULL,
    overwrite = FALSE,
    verbose = TRUE,
    timeout_seconds = 300
) {
  # --- Input Validation ---
  if (missing(dest_dir)) stop("`dest_dir` is required.", call. = FALSE)
  if (missing(resolution) || !is.character(resolution) || length(resolution) != 1) {
    stop("`resolution` must be a single character string.", call. = FALSE)
  }
  valid_resolutions = c("daily", "monthly", "seasonal", "yearly")
  if (!tolower(resolution) %in% valid_resolutions) {
    stop(glue::glue("Invalid `resolution`. Must be one of: {paste(valid_resolutions, collapse = ', ')}."), call. = FALSE)
  }
  resolution = tolower(resolution)

  if (missing(year) || !is.numeric(year) || year %% 1 != 0 || length(year) != 1) {
    stop("`year` must be a single integer.", call. = FALSE)
  }
  year = as.integer(year)

  if (missing(variable_type) || !is.character(variable_type) || length(variable_type) != 1) {
    stop("`variable_type` must be a single character string.", call. = FALSE)
  }

  current_resource_id = NULL
  params = list(year = year, variable_type = toupper(variable_type)) # Standardize variable_type to upper

  # --- Determine resource_id and params based on resolution ---
  if (resolution == "daily") {
    current_resource_id = "spartacus-v2-1d-1km"
  } else if (resolution == "monthly") {
    current_resource_id = "spartacus-v2-1m-1km"
    # If your schema for monthly data expects a 'month' parameter:
    # if (is.null(month) || !is.numeric(month) || month < 1 || month > 12 || month %% 1 != 0) {
    #   stop("`month` (1-12) is required for monthly resolution if schema expects it.", call. = FALSE)
    # }
    # params$month = as.integer(month)
  } else if (resolution == "seasonal") {
    current_resource_id = "spartacus-v2-1q-1km" # Corrected ID
    if (is.null(season_code) || !is.character(season_code) || length(season_code) != 1 || !nzchar(season_code)) {
      stop("`season_code` (e.g., 'DJF', 'MAM') is required for seasonal resolution.", call. = FALSE)
    }
    params$season_code = toupper(season_code) # Standardize to upper
  } else if (resolution == "yearly") {
    current_resource_id = "spartacus-v2-1y-1km"
  } else {
    stop(glue::glue("Unhandled resolution: {resolution}"), call. = FALSE) # Should be caught earlier
  }

  if (is.null(current_resource_id)) {
    cli::cli_abort("Could not determine resource_id for resolution '{resolution}'. This is an internal logic error.")
    return(NA_character_)
  }

  if (verbose) {
    cli::cli_alert_info("Targeting SPARTACUS resolution: {resolution}")
    cli::cli_alert_info("Using resource ID: {current_resource_id}")
  }

  # Call the internal schema-based function
  # (Make sure geosphere_download_from_schema is available in the environment,
  # or if in a package, call it as YourPackageName:::geosphere_download_from_schema
  # or ensure it's accessible if not exported)
  return(geosphere_download_from_schema(
    dest_dir = dest_dir,
    resource_id = current_resource_id,
    params = params,
    base_data_url = base_data_url,
    user_agent = user_agent,
    overwrite = overwrite,
    verbose = verbose,
    timeout_seconds = timeout_seconds
  ))
}
