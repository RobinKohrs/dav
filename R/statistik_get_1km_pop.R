#' Get 1km Grid Population Data from Statistik Austria
#'
#' Downloads population counts per 1km INSPIRE grid cell from the Statistik
#' Austria WMS service. Uses pre-computed cell centroids to issue one
#' GetFeatureInfo request per grid cell.
#'
#' @param year Integer. The reference year (e.g. 2025). Passed to the WMS as
#'   `YEAR:{year}-01-01`.
#' @param poi An sf object with point geometry and a `cell_id` column
#'   (standard INSPIRE 1km cell identifier, e.g. `"1kmN2390E4636"`). Must be
#'   in EPSG:4326 or any CRS (will be reprojected to EPSG:3857 automatically).
#'   Defaults to the bundled [at_1km_centroids] dataset covering all populated
#'   1km cells in Austria.
#' @param sleep_ms Integer. Delay in milliseconds between requests (default: 10).
#' @param cache_dir Character. Path to a directory used to store and resume
#'   intermediate download state. A CSV file named
#'   `pop_1km_<year>.csv` is written after each request. On subsequent calls
#'   with the same `year`, already-queried cells are skipped automatically.
#'   Defaults to `"/Volumes/rr/geodata/österreich/population_1km"`. Set to
#'   `NULL` to disable caching.
#' @param verbose Logical. If `TRUE` (default), prints progress messages.
#'
#' @return A data frame with columns `cell_id` and `hws` (Hauptwohnsitz —
#'   number of persons with main residence in the cell), deduplicated by
#'   `cell_id`. Returns `NULL` if no features were collected.
#'
#' @examples
#' \dontrun{
#' # Austria-wide 1km population grid for 2025
#' statistik_get_1km_pop(2025)
#'
#' # Subset to Vienna cells only
#' wien_cells <- at_1km_centroids[sf::st_within(
#'   at_1km_centroids,
#'   sf::st_transform(wien_poly, 4326),
#'   sparse = FALSE
#' )[, 1], ]
#' statistik_get_1km_pop(2025, poi = wien_cells)
#'
#' # Resumable download with custom cache location
#' statistik_get_1km_pop(2025, cache_dir = "data/cache")
#' }
#'
#' @export
statistik_get_1km_pop <- function(
  year,
  poi       = at_1km_centroids,
  sleep_ms  = 10,
  cache_dir = "/Volumes/rr/geodata/österreich/population_1km",
  verbose   = TRUE
) {
  if (!is.numeric(year) || length(year) != 1) {
    stop("year must be a single numeric value")
  }
  if (!inherits(poi, "sf")) {
    stop("poi must be an sf object")
  }
  if (!"cell_id" %in% names(poi)) {
    stop("poi must have a cell_id column")
  }
  if (!is.null(cache_dir) && !dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
    if (verbose) message("Created cache_dir: ", cache_dir)
  }

  BUFFER  <- 1L  # metres around centroid
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
      "GT_RASTER:L001000;V1:hws;V2:hws;GEOM:T_L001000;v2filter:0;"
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

  poi    <- sf::st_transform(poi, 3857)
  coords <- sf::st_coordinates(poi)
  total  <- nrow(poi)

  result_rows   <- data.frame(
    queried_cell_id = character(),
    feat_id         = character(),
    cell_id         = character(),
    hws             = character(),
    stringsAsFactors = FALSE
  )
  seen_feat_ids   <- character(0)
  queried_cell_ids <- character(0)

  cache_path <- NULL
  if (!is.null(cache_dir)) {
    cache_path <- file.path(cache_dir, sprintf("pop_1km_%d.csv", year))
    if (file.exists(cache_path)) {
      result_rows      <- utils::read.csv(cache_path, colClasses = "character")
      seen_feat_ids    <- unique(result_rows$feat_id)
      queried_cell_ids <- unique(result_rows$queried_cell_id)
      if (verbose) {
        cli::cli_alert_info(paste0(
          "Resuming from cache: ", nrow(result_rows), " features, ",
          length(queried_cell_ids), "/", total, " cells already queried."
        ))
      }
    }
  }

  if (verbose) {
    cli::cli_alert_info(
      "Downloading 1km population for {year} ({total} grid cells, {length(queried_cell_ids)} cached)..."
    )
  }

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
    bbox_str <- paste(cx - BUFFER, cy - BUFFER, cx + BUFFER, cy + BUFFER,
                      sep = ",")

    params <- c(base_params, list(BBOX = bbox_str))

    tryCatch(
      {
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
        features <- data$features %||% list()

        new_count <- 0L
        for (feat in features) {
          feat_id <- feat$id
          if (!is.null(feat_id) && !feat_id %in% seen_feat_ids) {
            seen_feat_ids <- c(seen_feat_ids, feat_id)
            result_rows   <- rbind(result_rows, data.frame(
              queried_cell_id = cid,
              feat_id         = as.character(feat_id),
              cell_id         = cid,
              hws             = as.character(feat$properties$V1),
              stringsAsFactors = FALSE
            ))
            new_count <- new_count + 1L
          }
        }

        # Always record that this cell was queried so resuming skips it
        if (new_count == 0L) {
          result_rows <- rbind(result_rows, data.frame(
            queried_cell_id = cid,
            feat_id         = NA_character_,
            cell_id         = cid,
            hws             = NA_character_,
            stringsAsFactors = FALSE
          ))
        }

        queried_cell_ids <- c(queried_cell_ids, cid)

        if (!is.null(cache_path)) {
          utils::write.csv(result_rows, cache_path, row.names = FALSE)
        }

        if (verbose) {
          cli::cli_progress_update(
            id     = pb,
            status = cid,
            inc    = 1L
          )
        }
      },
      error = function(e) {
        if (verbose) {
          cli::cli_alert_warning("Error on {cid}: {conditionMessage(e)}")
        }
      }
    )

    Sys.sleep(sleep_ms / 1000)
  }

  if (nrow(result_rows) == 0L) {
    message("No features collected.")
    return(NULL)
  }

  if (verbose) {
    cli::cli_progress_done(id = pb)
    cli::cli_alert_success("Done! Collected {nrow(result_rows)} cells for {year}.")
  }

  result_rows |>
    dplyr::filter(!is.na(hws)) |>
    dplyr::select(cell_id, hws) |>
    dplyr::distinct(cell_id, .keep_all = TRUE) |>
    dplyr::mutate(hws = as.integer(hws))
}
