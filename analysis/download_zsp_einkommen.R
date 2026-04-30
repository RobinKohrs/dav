## Download all ZSP income data — all variables × all years, Austria-wide
## Output: /Volumes/rr/geodata/österreich/einkommen_zählsprengel/
##   zsp_einkommen_<income_var>_<year>.csv  (cache / resumable intermediate)
##   zsp_einkommen_<income_var>_<year>_final.csv  (cleaned final output)
##
## Re-running this script is safe: already-downloaded Zählsprengel are skipped.

library(davR)

YEARS       <- 2012:2022
INCOME_VARS <- c("pers_geseink", "pers_netto", "hh_geseink", "hh_netto")
CACHE_DIR   <- "/Volumes/rr/geodata/österreich/einkommen_zählsprengel"

combinations <- expand.grid(
  year       = YEARS,
  income_var = INCOME_VARS,
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(combinations))) {
  yr  <- combinations$year[i]
  var <- combinations$income_var[i]

  final_path <- file.path(CACHE_DIR, sprintf("zsp_einkommen_%s_%d_final.csv", var, yr))

  if (file.exists(final_path)) {
    message(sprintf("[%d/%d] SKIP  %s / %d — final CSV already exists.", i, nrow(combinations), var, yr))
    next
  }

  message(sprintf("\n[%d/%d] START %s / %d", i, nrow(combinations), var, yr))

  result <- tryCatch(
    statistik_get_zsp_einkommen(
      year       = yr,
      income_var = var,
      cache_dir  = CACHE_DIR,
      verbose    = TRUE
    ),
    error = function(e) {
      message(sprintf("ERROR on %s / %d: %s", var, yr, conditionMessage(e)))
      NULL
    }
  )

  if (!is.null(result)) {
    utils::write.csv(result, final_path, row.names = FALSE)
    message(sprintf("Saved: %s", final_path))
  }
}

message("\nAll done.")
