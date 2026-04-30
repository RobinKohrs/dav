#' Get Zählsprengel Income Data from Statistik Austria
#'
#' Downloads income statistics per Zählsprengel from the Statistik Austria WMS
#' service. Uses poles of inaccessibility or centroids to query each district
#' precisely with a single request per Zählsprengel.
#'
#' Four income variables are available:
#' \describe{
#'   \item{`"pers_geseink"`}{Mean total income incl. transfer payments per person.}
#'   \item{`"pers_netto"`}{Mean net income per person.}
#'   \item{`"hh_geseink"`}{Mean total income incl. transfer payments per household.}
#'   \item{`"hh_netto"`}{Mean net income per household.}
#' }
#'
#' @param year Integer. The year for which to download income data (2012–2022).
#' @param income_var Character. Which income variable to download. One of
#'   `"pers_geseink"` (default), `"pers_netto"`, `"hh_geseink"`, `"hh_netto"`.
#' @param poi An sf object with point geometry (poles of inaccessibility or
#'   centroids) and a `ZGEB` column identifying each Zählsprengel. Must be in
#'   EPSG:3857 or any CRS (will be reprojected automatically). Defaults to the
#'   bundled [wien_income_poi] dataset covering all Vienna Zählsprengel.
#'   For Austria-wide data use the `at_zsp_poi` dataset.
#' @param sleep_ms Integer. Delay in milliseconds between requests (default: 100).
#' @param cache_dir Character. Path to a directory used to store and resume
#'   intermediate download state. A CSV file named
#'   `zsp_einkommen_<income_var>_<year>.csv` is written after each request.
#'   On subsequent calls with the same arguments, already-queried Zählsprengel
#'   are skipped automatically. Defaults to
#'   `"/Volumes/rr/geodata/österreich/einkommen_zählsprengel"`. Set to NULL
#'   to disable caching.
#' @param verbose Logical. If TRUE (default), prints progress messages.
#'
#' @return A data frame with columns `ID`, `g_id`, and the income variable name
#'   (e.g. `geseink_mean`), deduplicated by `g_id`. Returns NULL if no features
#'   were collected.
#'
#' @examples
#' \dontrun{
#' # Gesamteinkommen per person for 2022 (Vienna, default poi)
#' statistik_get_zsp_einkommen(2022)
#'
#' # Nettoeinkommen per person
#' statistik_get_zsp_einkommen(2022, income_var = "pers_netto")
#'
#' # Household total income, resumable download cached to disk
#' statistik_get_zsp_einkommen(2022, income_var = "hh_geseink",
#'   cache_dir = "data/cache")
#'
#' # Austria-wide using at_zsp_poi
#' statistik_get_zsp_einkommen(2022, poi = at_zsp_poi)
#' }
#'
#' @export
statistik_get_zsp_einkommen <- function(
  year,
  income_var = c("pers_geseink", "pers_netto", "hh_geseink", "hh_netto"),
  poi = at_income_poi,
  sleep_ms = 10,
  cache_dir = "/Volumes/rr/geodata/österreich/einkommen_zählsprengel",
  verbose = TRUE
) {
  income_var <- match.arg(income_var)

  if (!is.numeric(year) || length(year) != 1) {
    stop("year must be a single numeric value")
  }
  if (year < 2012 || year > 2022) {
    stop("year must be between 2012 and 2022")
  }
  if (!inherits(poi, "sf")) {
    stop("poi must be an sf object")
  }
  if (!"ZGEB" %in% names(poi)) {
    stop("poi must have a ZGEB column")
  }
  if (!is.null(cache_dir) && !dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
    if (verbose) message("Created cache_dir: ", cache_dir)
  }

  # Map income_var to VIEWPARAMS components
  var_cfg <- list(
    pers_geseink = list(gt = "v_pers", v1 = "geseink_mean",     v2 = "geseink_sum"),
    pers_netto   = list(gt = "v_pers", v1 = "netto_mean",       v2 = "netto_sum"),
    hh_geseink   = list(gt = "v_hh",  v1 = "phh_geseink_mean", v2 = "phh_geseink_sum"),
    hh_netto     = list(gt = "v_hh",  v1 = "phh_netto_mean",   v2 = "phh_netto_sum")
  )
  cfg <- var_cfg[[income_var]]

  BUFFER <- 1 # metres around each point
  wms_url <- "https://www.statistik.at/gs-atlas/ATLAS_IMAP/wms"

  base_params <- list(
    QUERY_LAYERS = "ATLAS_IMAP:ZSP_POLY_LUE_DS_PG",
    INFO_FORMAT = "application/json",
    REQUEST = "GetFeatureInfo",
    SERVICE = "WMS",
    VERSION = "1.3.0",
    FORMAT = "image/png",
    STYLES = "ATLAS_IMAP:POLY_VAR_8_DS_ZSP",
    TRANSPARENT = "true",
    feature_count = "10",
    LAYERS = "ATLAS_IMAP:ZSP_POLY_LUE_DS_PG",
    VIEWPARAMS = glue::glue(
      "YEAR:{year}-10-31;GT:{cfg$gt};V1:{cfg$v1};V2:{cfg$v2};",
      "V1_ABS:{cfg$v2};GEN:100;V2FILTER:-1;WIENFLAG:23;"
    ),
    ENV = "c1:#ffffcc;c2:#ffeda0;c3:#fed976;c4:#feb24c;c5:#fd8d3c;c6:#fc4e2a;c7:#e31a1c;c8:#b10026;s1:25000;s2:27500;s3:30000;s4:32500;s5:35000;s6:37500;s7:40000;ol_color:#e4e4e4;ol_sw:0.8;ol_so:0.9",
    WIDTH = "300",
    HEIGHT = "300",
    CRS = "EPSG:3857",
    I = "150",
    J = "150"
  )

  poi <- sf::st_transform(poi, 3857)
  coords <- sf::st_coordinates(poi)
  total <- nrow(poi)

  # In-memory accumulator — columns: queried_zgeb, feat_id, ID, V1
  result_rows   <- data.frame(queried_zgeb = character(), feat_id = character(),
    ID = character(), V1 = character(),
    stringsAsFactors = FALSE)
  seen_feat_ids <- character(0)   # WMS feature IDs (dedup)
  queried_zgebs <- character(0)   # ZGEB values already requested (for resuming)

  cache_path <- NULL
  if (!is.null(cache_dir)) {
    cache_path <- file.path(
      cache_dir,
      sprintf("zsp_einkommen_%s_%d.csv", income_var, year)
    )
    if (file.exists(cache_path)) {
      result_rows   <- utils::read.csv(cache_path, colClasses = "character")
      seen_feat_ids <- unique(result_rows$feat_id)
      queried_zgebs <- unique(result_rows$queried_zgeb)
      if (verbose) {
        message(sprintf(
          "Resuming from cache: %d features, %d/%d ZSP already queried.",
          nrow(result_rows), length(queried_zgebs), total
        ))
      }
    }
  }

  if (verbose) {
    message(glue::glue(
      "\nDownloading ZSP income [{income_var}] for {year} ",
      "({total} Zählsprengel, {length(queried_zgebs)} cached)..."
    ))
  }

  for (i in seq_len(nrow(poi))) {
    zgeb <- poi$ZGEB[i]

    if (zgeb %in% queried_zgebs) {
      next
    }

    cx <- coords[i, "X"]
    cy <- coords[i, "Y"]
    bbox_str <- paste(cx - BUFFER, cy - BUFFER, cx + BUFFER, cy + BUFFER, sep = ",")

    params <- c(base_params, list(BBOX = bbox_str))

    tryCatch(
      {
        resp <- httr::GET(
          wms_url,
          query = params,
          httr::add_headers(
            `User-Agent` = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            `Accept` = "application/json, text/javascript, */*; q=0.01",
            `Referer` = "https://www.statistik.at/"
          )
        )
        httr::stop_for_status(resp)

        data <- jsonlite::fromJSON(
          httr::content(resp, as = "text", encoding = "UTF-8"),
          simplifyVector = FALSE
        )
        features <- data$features %||% list()

        new_count <- 0
        for (feat in features) {
          feat_id <- feat$id
          if (!is.null(feat_id) && !feat_id %in% seen_feat_ids) {
            seen_feat_ids <- c(seen_feat_ids, feat_id)
            result_rows <- rbind(result_rows, data.frame(
              queried_zgeb = zgeb,
              feat_id      = feat_id,
              ID           = as.character(feat$properties$ID),
              V1           = as.character(feat$properties$V1),
              stringsAsFactors = FALSE
            ))
            new_count <- new_count + 1
          }
        }

        queried_zgebs <- c(queried_zgebs, zgeb)

        if (!is.null(cache_path)) {
          utils::write.csv(result_rows, cache_path, row.names = FALSE)
        }

        if (verbose) {
          if (new_count > 0) {
            message(sprintf(
              "[%d/%d] ZGEB %s: %d new feature(s). Total: %d",
              i, total, zgeb, new_count, nrow(result_rows)
            ))
          } else {
            message(sprintf("[%d/%d] ZGEB %s: No new features.", i, total, zgeb))
          }
        }
      },
      error = function(e) {
        if (verbose) message(sprintf("Error on ZGEB %s: %s", zgeb, conditionMessage(e)))
      }
    )

    Sys.sleep(sleep_ms / 1000)
  }

  if (nrow(result_rows) == 0) {
    message("No features collected.")
    return(NULL)
  }

  if (verbose) {
    message(glue::glue(
      "\nDone! Collected {nrow(result_rows)} features ",
      "for {income_var} / {year}."
    ))
  }

  result_rows |>
    dplyr::mutate(
      g_id = paste0(stringr::str_sub(ID, 2, 3), stringr::str_sub(ID, 6, 8))
    ) |>
    dplyr::select(ID, g_id, V1) |>
    dplyr::group_by(g_id) |>
    dplyr::filter(
      dplyr::case_when(
        dplyr::n() > 1 ~ stringr::str_sub(ID, 4, 5) == "01",
        .default = TRUE
      )
    ) |>
    dplyr::mutate(V1 = as.numeric(V1)) |>
    dplyr::rename(!!cfg$v1 := V1) |>
    dplyr::ungroup()
}
