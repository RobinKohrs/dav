# --- GEOSPHERE_DATA_SCHEMAS ---
# --- RESOURCE IDs ARE NOW CORRECT. FILENAME TEMPLATES AND PARAMETERS ARE EDUCATED GUESSES ---
# --- YOU MUST VERIFY filename_templates, variable codes, and season codes! ---
GEOSPHERE_DATA_SCHEMAS = list(
  # --- SPARTACUS v2 Daily Data ---
  "spartacus-v2-1d-1km" = list(
    description = "SPARTACUS v2 Daily Gridded Data (1km resolution)",
    parameters = list(
      year = list(
        type = "integer",
        description = "Year of the data (e.g., 2020)."
      ),
      variable_type = list(
        type = "character",
        description = "Climate variable: TX (Max Temp), TN (Min Temp), RR (Precip), SL (Global Rad), SD (Snow Depth). Verify exact codes!",
        # Assuming similar variables to your first example, but check Geosphere for "spartacus-v2-1d-1km" specifics
        allowed_values = c("TX", "TN", "RR", "SL", "SD", "SA") # Added SA based on other descriptions
      )
    ),
    # ASSUMPTION: Filename pattern is similar to your first example
    # Example: SPARTACUS2-DAILY_TX_2020.nc
    filename_template = "SPARTACUS2-DAILY_{toupper(variable_type)}_{year}.nc",
    resource_subpath_parts_template = NULL # Assuming no subpath
  ),

  # --- SPARTACUS v2 Monthly Data ---
  "spartacus-v2-1m-1km" = list(
    description = "SPARTACUS v2 Monthly Gridded Data (1km resolution)",
    parameters = list(
      year = list(type = "integer"),
      variable_type = list(
        type = "character",
        description = "Climate variable: TM (Mean Temp), RR (Precip), SA (Sunshine Duration). Verify exact codes!",
        allowed_values = c("TM", "RR", "SA") # Based on general descriptions
      )
    ),
    filename_template = "SPARTACUS2-MONTHLY_{toupper(variable_type)}_{year}.nc",
    resource_subpath_parts_template = c(
      "filelisting",
      "{toupper(variable_type)}"
    ) # Added subpath structure
  ),

  # --- SPARTACUS v2 Seasonal (Quarterly) Data ---
  "spartacus-v2-1q-1km" = list(
    # Corrected from 1s to 1q
    description = "SPARTACUS v2 Seasonal (Quarterly) Gridded Data (1km resolution)",
    parameters = list(
      year = list(type = "integer"),
      variable_type = list(
        type = "character",
        description = "Climate variable: TM (Mean Temp), RR (Precip), SA (Sunshine Duration). Verify exact codes!",
        allowed_values = c("TM", "RR", "SA")
      ),
      season_code = list(
        type = "character",
        description = "Season code (e.g., 'DJF', 'MAM', 'JJA', 'SON'). Verify format!",
        allowed_values = c("DJF", "MAM", "JJA", "SON") # Common meteorological season codes
      )
    ),
    # ASSUMPTION: Example: SPARTACUS2-SEASONAL_TM_2020_JJA.nc
    filename_template = "SPARTACUS2-SEASONAL_{toupper(variable_type)}_{year}_{toupper(season_code)}.nc",
    resource_subpath_parts_template = NULL # Assuming no subpath
  ),

  # --- SPARTACUS v2 Yearly Data ---
  "spartacus-v2-1y-1km" = list(
    description = "SPARTACUS v2 Yearly Gridded Data (1km resolution)",
    parameters = list(
      year = list(type = "integer"),
      variable_type = list(
        type = "character",
        description = "Climate variable: TM (Mean Temp), RR (Precip), SA (Sunshine Duration). Verify exact codes!",
        allowed_values = c("TM", "RR", "SA")
      )
    ),
    # UPDATED: Files are organized in subfolders by variable type
    filename_template = "SPARTACUS2-YEARLY_{toupper(variable_type)}_{year}.nc",
    resource_subpath_parts_template = c(
      "filelisting",
      "{toupper(variable_type)}"
    ) # Files are in filelisting/VARIABLE subfolders
  )
)
# --- End of GEOSPHERE_DATA_SCHEMAS ---

# Use usethis to save this list as internal package data (in R/sysdata.rda)
# This makes GEOSPHERE_DATA_SCHEMAS available to your package functions
# without needing to export it or load it explicitly.
# Ensure your current working directory is the package root when running this.
if (requireNamespace("usethis", quietly = TRUE)) {
  usethis::use_data(GEOSPHERE_DATA_SCHEMAS, internal = TRUE, overwrite = TRUE)
  message("GEOSPHERE_DATA_SCHEMAS saved to R/sysdata.rda")
} else {
  warning(
    "`usethis` package not found. Cannot save GEOSPHERE_DATA_SCHEMAS to R/sysdata.rda automatically.\n",
    "Please install `usethis` and run this script again, or manually save the object:\n",
    "save(GEOSPHERE_DATA_SCHEMAS, file = \"R/sysdata.rda\")"
  )
}
