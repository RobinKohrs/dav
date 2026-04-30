#' Download Population Counts for the Statistik Austria INSPIRE Grid
#'
#' Downloads the 1km or 250m INSPIRE LAEA grid shapefile from Statistik Austria,
#' extracts cell centroids, and queries the WMS `GetFeatureInfo` endpoint to
#' obtain population counts (Hauptwohnsitz) per grid cell.
#'
#' @param year Integer. The reference year (e.g. 2025). Passed to the WMS as
#'   `YEAR:{year}-01-01`.
#' @param resolution Character. Grid resolution: `"1km"` (default) or `"250m"`.
#' @param sleep_ms Integer. Delay in milliseconds between requests (default: 10).
#' @param cache_dir Character. Directory used to store the downloaded grid
#'   shapefile and the intermediate WMS query results. A CSV file named
#'   `pop_1km_<year>.csv` or `pop_250m_<year>.csv` is written after each
#'   request, enabling resumable downloads. Defaults to
#'   `"/Volumes/rr/geodata/oesterreich/population_grid"`. Set to `NULL` to
#'   disable caching (grid and results are kept only in memory / tempdir).
#' @param verbose Logical. If `TRUE` (default), prints progress messages.
#'
#' @return A data frame with columns `cell_id` (INSPIRE grid cell identifier)
#'   and `hws` (integer, Hauptwohnsitz — persons with main residence in the
#'   cell). Cells with no registered population are omitted.
#'
#' @examples
#' \dontrun{
#' # 1km grid, Austria-wide
#' pop1km  <- statistik_get_pop_grid(2025)
#'
#' # 250m grid (much larger — ~1.4 million cells)
#' pop250m <- statistik_get_pop_grid(2025, resolution = "250m")
#'
#' # Join back to the grid polygons
#' grid   <- statistik_get_1km_grid()
#' result <- dplyr::left_join(grid, pop1km, by = "cell_id")
#' }
#'
#' @export
statistik_get_pop_grid <- function(
  year,
  resolution = c("1km", "250m"),
  sleep_ms   = 10,
  cache_dir  = "/Volumes/rr/geodata/oesterreich/population_grid",
  verbose    = TRUE
) {
  resolution <- match.arg(resolution)

  if (!is.numeric(year) || length(year) != 1) {
    stop("year must be a single numeric value")
  }

  # ---- resolution-dependent settings ----------------------------------------
  cfg <- switch(resolution,
    "1km" = list(
      zip_url     = paste0(
        "https://data.statistik.gv.at/data/",
        "OGDEXT_RASTER_1_STATISTIK_AUSTRIA_L001000_LAEA.zip"
      ),
      raster_id   = "L001000",
      cache_csv   = sprintf("pop_1km_%d.csv", year),
      grid_subdir = "grid_1km"
    ),
    "250m" = list(
      zip_url     = paste0(
        "https://data.statistik.gv.at/data/",
        "OGDEXT_RASTER_1_STATISTIK_AUSTRIA_L000250_LAEA_Bundeslaender.zip"
      ),
      raster_id   = "L000250",
      cache_csv   = sprintf("pop_250m_%d.csv", year),
      grid_subdir = "grid_250m"
    )
  )

  # ---- cache paths -----------------------------------------------------------
  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    grid_dir   <- file.path(cache_dir, cfg$grid_subdir)
    zip_path   <- file.path(cache_dir, paste0(cfg$grid_subdir, ".zip"))
    cache_path <- file.path(cache_dir, cfg$cache_csv)
  } else {
    grid_dir   <- tempfile()
    zip_path   <- tempfile(fileext = ".zip")
    cache_path <- NULL
  }

  # ---- download + extract grid -----------------------------------------------
  shp_file <- .find_shp(grid_dir)

  if (is.null(shp_file)) {
    if (!file.exists(zip_path)) {
      if (verbose) cli::cli_alert_info(
        "Downloading {resolution} grid from Statistik Austria..."
      )
      resp <- httr::GET(
        cfg$zip_url,
        httr::write_disk(zip_path, overwrite = TRUE),
        httr::progress()
      )
      if (httr::http_error(resp)) {
        stop("Download failed: HTTP ", httr::status_code(resp), " for ", cfg$zip_url)
      }
    } else {
      if (verbose) cli::cli_alert_info("Using cached zip: {zip_path}")
    }
    if (verbose) cli::cli_alert_info("Extracting grid shapefile...")
    dir.create(grid_dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip_path, exdir = grid_dir)
    shp_file <- .find_shp(grid_dir)
    if (is.null(shp_file)) stop("No .shp found after extracting ", zip_path)
  } else {
    if (verbose) cli::cli_alert_info("Using cached grid: {shp_file}")
  }

  # ---- extract centroids -----------------------------------------------------
  if (verbose) cli::cli_alert_info("Reading grid and computing centroids...")
  grid_sf <- sf::st_read(shp_file, quiet = TRUE)

  id_col <- intersect(c("cellcode", "GRD_ID", "cell_id", "GRID_ID"), names(grid_sf))
  if (length(id_col) == 0) stop("Cannot find cell ID column in grid shapefile.")
  id_col <- id_col[[1]]

  centroids <- sf::st_centroid(grid_sf)
  poi <- sf::st_sf(
    data.frame(cell_id = grid_sf[[id_col]], stringsAsFactors = FALSE),
    geometry = sf::st_geometry(centroids)
  )
  poi    <- sf::st_transform(poi, 3857)
  coords <- sf::st_coordinates(poi)
  total  <- nrow(poi)

  if (verbose) cli::cli_alert_info(
    "{resolution} grid: {total} cells to query for year {year}."
  )

  # ---- WMS setup -------------------------------------------------------------
  BUFFER  <- 1L
  wms_url <- "https://www.statistik.at/gs-atlas/ATLAS_IMAP/wms"

  base_params <- list(
    QUERY_LAYERS  = "ATLAS_IMAP:RASTER_STATATLAS_PG",
    INFO_FORMAT   = "application/json",
    REQUEST       = "GetFeatureInfo",
    SERVICE       = "WMS",
    VERSION       = "1.3.0",
    FORMAT        = "image/png",
    STYLES        = "ATLAS_IMAP:POLY_VAR_8_DS",
    TRANSPARENT   = "true",
    feature_count = "1",
    LAYERS        = "ATLAS_IMAP:RASTER_STATATLAS_PG",
    VIEWPARAMS    = glue::glue(
      "gt_v:daten_popreg;GT:t_agesex;YEAR:{year}-01-01;",
      "GT_RASTER:{cfg$raster_id};V1:hws;V2:hws;GEOM:T_{cfg$raster_id};v2filter:0;"
    ),
    ENV = paste0(
      "c1:#ffffcc;c2:#ffeda0;c3:#fed976;c4:#feb24c;c5:#fd8d3c;",
      "c6:#fc4e2a;c7:#e31a1c;c8:#b10026;",
      "s1:10;s2:25;s3:50;s4:100;s5:500;s6:1000;s7:5000;",
      "ol_color:#ffffff;ol_sw:0.2;ol_so:0.3"
    ),
    WIDTH  = "101",
    HEIGHT = "101",
    CRS    = "EPSG:3857",
    I      = "50",
    J      = "50"
  )

  # ---- load cache ------------------------------------------------------------
  result_rows <- data.frame(
    queried_cell_id  = character(),
    feat_id          = character(),
    cell_id          = character(),
    hws              = character(),
    stringsAsFactors = FALSE
  )
  seen_feat_ids    <- character(0)
  queried_cell_ids <- character(0)

  if (!is.null(cache_path) && file.exists(cache_path)) {
    result_rows      <- utils::read.csv(cache_path, colClasses = "character")
    seen_feat_ids    <- unique(result_rows$feat_id)
    queried_cell_ids <- unique(result_rows$queried_cell_id)
    if (verbose) cli::cli_alert_info(
      "Resuming from cache: {nrow(result_rows)} features, ",
      "{length(queried_cell_ids)}/{total} cells already queried."
    )
  }

  # ---- query loop ------------------------------------------------------------
  if (verbose) cli::cli_alert_info(
    "Downloading {resolution} population for {year} ",
    "({total} cells, {length(queried_cell_ids)} cached)..."
  )

  pb <- if (verbose) {
    cli::cli_progress_bar(
      total  = total - length(queried_cell_ids),
      format = paste0(
        "{cli::pb_spin} {cli::pb_current}/{cli::pb_total} ",
        "{cli::pb_bar} | {cli::pb_percent} | elapsed: {cli::pb_elapsed} | ",
        "eta: {cli::pb_eta} | {cli::pb_status}"
      ),
      clear  = FALSE
    )
  } else NULL

  for (i in seq_len(nrow(poi))) {
    cid <- poi$cell_id[i]
    if (cid %in% queried_cell_ids) next

    cx       <- coords[i, "X"]
    cy       <- coords[i, "Y"]
    bbox_str <- paste(cx - BUFFER, cy - BUFFER, cx + BUFFER, cy + BUFFER, sep = ",")
    params   <- c(base_params, list(BBOX = bbox_str))

    tryCatch({
      resp <- httr::GET(
        wms_url,
        query = params,
        httr::add_headers(
          `User-Agent` = paste0(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ",
            "AppleWebKit/537.36 (KHTML, like Gecko) ",
            "Chrome/120.0.0.0 Safari/537.36"
          ),
          `Accept`  = "application/json, text/javascript, */*; q=0.01",
          `Referer` = "https://www.statistik.at/"
        )
      )
      httr::stop_for_status(resp)

      data     <- jsonlite::fromJSON(
        httr::content(resp, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE
      )
      features  <- data$features %||% list()
      new_count <- 0L

      for (feat in features) {
        feat_id <- feat$id
        if (!is.null(feat_id) && !feat_id %in% seen_feat_ids) {
          seen_feat_ids <- c(seen_feat_ids, feat_id)
          result_rows   <- rbind(result_rows, data.frame(
            queried_cell_id  = cid,
            feat_id          = as.character(feat_id),
            cell_id          = cid,
            hws              = as.character(feat$properties$V1),
            stringsAsFactors = FALSE
          ))
          new_count <- new_count + 1L
        }
      }

      if (new_count == 0L) {
        result_rows <- rbind(result_rows, data.frame(
          queried_cell_id  = cid,
          feat_id          = NA_character_,
          cell_id          = cid,
          hws              = NA_character_,
          stringsAsFactors = FALSE
        ))
      }

      queried_cell_ids <- c(queried_cell_ids, cid)

      if (!is.null(cache_path)) {
        utils::write.csv(result_rows, cache_path, row.names = FALSE)
      }

      if (verbose) cli::cli_progress_update(id = pb, status = cid, inc = 1L)
    },
    error = function(e) {
      if (verbose) cli::cli_alert_warning("Error on {cid}: {conditionMessage(e)}")
    })

    Sys.sleep(sleep_ms / 1000)
  }

  if (nrow(result_rows) == 0L) {
    message("No features collected.")
    return(NULL)
  }

  if (verbose) {
    cli::cli_progress_done(id = pb)
    cli::cli_alert_success(
      "Done! Collected {nrow(result_rows)} cells for {year} ({resolution})."
    )
  }

  result_rows |>
    dplyr::filter(!is.na(hws)) |>
    dplyr::select(cell_id, hws) |>
    dplyr::distinct(cell_id, .keep_all = TRUE) |>
    dplyr::mutate(hws = as.integer(hws))
}
