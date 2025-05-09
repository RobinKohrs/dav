# data-raw/prepare_geosphere_schemas.R

# This script defines the schemas for accessing Geosphere Austria data
# and saves them as internal package data (R/sysdata.rda).
# Run this script whenever you add or modify a schema.

## Define known Geosphere data schemas
## This list is maintained by the package developer based on knowledge of the datasets.
GEOSPHERE_DATA_SCHEMAS <- list(
  "spartacus-v2-1d-1km" = list(
    description = "SPARTACUS v2 Daily 1km Gridded Data",
    resource_subpath_parts_template = c("filelisting", "{variable_type}"),
    filename_template = "SPARTACUS2-DAILY_{variable_type}_{year}.nc",
    parameters = list(
      year = list(type = "integer", example = 2020, notes = "Four-digit year, e.g., 1961-current"),
      variable_type = list(
        type = "character",
        allowed_values = c("TX", "TN", "RR", "GLOB", "SD"), # TX:MaxTemp, TN:MinTemp, RR:Precip, GLOB:GlobalRad, SD:SnowDepth
        example = "TX",
        notes = "TX: Max Temp, TN: Min Temp, RR: Precipitation, GLOB: Global Radiation, SD: Snow Depth"
      )
    )
  ),
  "apolis-short-daily-dir-hori" = list(
    description = "APOLIS Shortwave Daily Direct Horizontal Sum (kWh/m^2)",
    resource_subpath_parts_template = c("daily", "DIR_hori_daysum_kWh"), # This seems fixed
    filename_template = "APOLIS-SHORT-DAILY_DIR_hori_daysum_kWh_{year}{month}.nc",
    parameters = list(
      year = list(type = "integer", example = 2006, notes = "Four-digit year, e.g., 2001-current"),
      month = list(type = "character", example = "01", notes = "Two-digit month, zero-padded (e.g., '01' for Jan, '12' for Dec)")
    )
  ),
  "vdl-standard-v1-1h-1km-era5land-downscaled" = list(
    description = "VDL Standard v1 Hourly 1km ERA5-Land Downscaled Data (INCA-analysed)",
    resource_subpath_parts_template = c("{year}", "{month}", "{variable_code}"), # e.g. 2022/01/t2m
    filename_template = "vdl-standard-v1_1h_1km_era5land-downscaled_{year}{month}{day}_{variable_code}.nc",
    parameters = list(
      year = list(type = "integer", example = 2022, notes = "Four-digit year"),
      month = list(type = "character", example = "01", notes = "Two-digit month, zero-padded"),
      day = list(type = "character", example = "01", notes = "Two-digit day, zero-padded"),
      variable_code = list(
        type = "character",
        allowed_values = c(
          "t2m", "td2m", "u10m", "v10m", "rh2m", "msl", "tp", "ssr", "str", "sd", "cloudcover"
          # t2m: Temp 2m, td2m: Dewpoint 2m, u10m/v10m: Wind, rh2m: RelHum, msl: Pressure,
          # tp: Total Precip, ssr: Surf Shortwave Rad, str: Surf Thermal Rad, sd: SnowDepth
        ),
        example = "t2m",
        notes = "Variable codes (e.g., t2m for 2m temperature)"
      )
    )
  )
  # Add more schemas here as you discover/need them.
  # For example:
  # "another-dataset-id" = list(
  #   description = "Another Dataset Example",
  #   resource_subpath_parts_template = c("some", "path"),
  #   filename_template = "datafile_{location_code}_{date_iso}.csv",
  #   parameters = list(
  #     location_code = list(type = "character", example = "VIENNA"),
  #     date_iso = list(type = "character", example = "2023-10-26", notes = "YYYY-MM-DD format")
  #   )
  # )
)

# Use usethis to save this list as internal package data (in R/sysdata.rda)
# This makes GEOSPHERE_DATA_SCHEMAS available to your package functions
# without needing to export it or load it explicitly.
# Ensure your current working directory is the package root when running this.
if (requireNamespace("usethis", quietly = TRUE)) {
  usethis::use_data(GEOSPHERE_DATA_SCHEMAS, internal = TRUE, overwrite = TRUE)
  message("GEOSPHERE_DATA_SCHEMAS saved to R/sysdata.rda")
} else {
  warning("`usethis` package not found. Cannot save GEOSPHERE_DATA_SCHEMAS to R/sysdata.rda automatically.\n",
          "Please install `usethis` and run this script again, or manually save the object:\n",
          "save(GEOSPHERE_DATA_SCHEMAS, file = \"R/sysdata.rda\")")
}
