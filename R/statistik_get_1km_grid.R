#' Download the Statistik Austria 1km LAEA Grid
#'
#' Downloads the official 1km INSPIRE LAEA grid polygon layer from
#' Statistik Austria's OGD portal, unzips it, reads it as an `sf` object,
#' and optionally joins population data.
#'
#' @param cache_dir Character. Directory where the zip and extracted shapefile
#'   are stored so repeated calls skip the download. Defaults to `tempdir()`.
#'   Set to `NULL` to always re-download.
#' @param verbose Logical. If `TRUE` (default), prints progress messages.
#'
#' @return An `sf` object with the 1km grid polygons in EPSG:3035 (LAEA Europe).
#'   Contains at minimum a `cell_id` column (`GRD_ID` renamed) plus any
#'   attributes bundled in the shapefile.
#'
#' @examples
#' \dontrun{
#' grid <- statistik_get_1km_grid()
#'
#' # Join with population data
#' pop  <- statistik_get_1km_pop(2025)
#' grid_pop <- dplyr::left_join(grid, pop, by = "cell_id")
#' }
#'
#' @export
statistik_get_1km_grid <- function(
  cache_dir = tempdir(),
  verbose   = TRUE
) {
  zip_url <- paste0(
    "https://data.statistik.gv.at/data/",
    "OGDEXT_RASTER_1_STATISTIK_AUSTRIA_L001000_LAEA.zip"
  )

  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }
    zip_path <- file.path(cache_dir, "at_1km_grid_laea.zip")
    shp_dir  <- file.path(cache_dir, "at_1km_grid_laea")
  } else {
    zip_path <- tempfile(fileext = ".zip")
    shp_dir  <- tempfile()
  }

  # Locate an already-extracted shapefile
  shp_file <- .find_shp(shp_dir)

  if (is.null(shp_file)) {
    if (!file.exists(zip_path)) {
      if (verbose) cli::cli_alert_info("Downloading 1km grid from Statistik Austria...")
      resp <- httr::GET(
        zip_url,
        httr::write_disk(zip_path, overwrite = TRUE),
        httr::progress()
      )
      if (httr::http_error(resp)) {
        stop("Download failed: HTTP ", httr::status_code(resp), " for ", zip_url)
      }
    } else {
      if (verbose) cli::cli_alert_info("Using cached zip: {zip_path}")
    }

    if (verbose) cli::cli_alert_info("Extracting zip...")
    dir.create(shp_dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip_path, exdir = shp_dir)
    shp_file <- .find_shp(shp_dir)
    if (is.null(shp_file)) {
      stop("No .shp file found after extracting ", zip_path)
    }
  } else {
    if (verbose) cli::cli_alert_info("Using cached shapefile: {shp_file}")
  }

  if (verbose) cli::cli_alert_info("Reading shapefile...")
  grid <- sf::st_read(shp_file, quiet = !verbose)

  # Normalise the cell_id column (Statistik Austria uses GRD_ID in this file)
  if ("GRD_ID" %in% names(grid) && !"cell_id" %in% names(grid)) {
    grid <- dplyr::rename(grid, cell_id = GRD_ID)
  } else if ("cellcode" %in% names(grid) && !"cell_id" %in% names(grid)) {
    grid <- dplyr::rename(grid, cell_id = cellcode)
  }

  if (verbose) cli::cli_alert_success("Done! {nrow(grid)} grid cells loaded.")
  grid
}

# Internal helper: find the first .shp in a directory tree
.find_shp <- function(dir) {
  if (!dir.exists(dir)) return(NULL)
  hits <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
  if (length(hits) == 0) NULL else hits[[1]]
}
