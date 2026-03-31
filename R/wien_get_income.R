#' Get Vienna Zählbezirk Income Data for a Specific Year
#'
#' Downloads income statistics per Zählbezirk (census district) for Vienna
#' from the Statistik Austria WMS service. Uses poles of inaccessibility
#' to query each district precisely with a single request per district.
#'
#' @param year Integer. The year for which to download income data (2012-2022).
#' @param poi An sf object with point geometry (poles of inaccessibility) and a
#'   `ZGEB` column identifying each Zählbezirk. Must be in EPSG:3857 or any
#'   CRS (will be reprojected automatically). Defaults to the bundled
#'   [wien_income_poi] dataset covering all Vienna Zählbezirke.
#' @param sleep_ms Integer. Delay in milliseconds between requests (default: 100).
#' @param download_dir Character. Optional path to a directory where the GeoJSON
#'   file will be saved as `wien_income_<year>.geojson`. If NULL (default), no
#'   file is written to disk.
#' @param verbose Logical. If TRUE (default), prints progress messages.
#'
#' @return A data frame with columns `ID`, `g_id`, and `V1` (mean income, numeric),
#'   deduplicated by `g_id`. Returns NULL if no features were collected.
#'
#' @examples
#' \dontrun{
#' # Get income data for 2022 using the bundled POI data
#' income_2022 <- wien_get_income(2022)
#'
#' # Use a custom poi sf object
#' poi <- sf::st_read("poi.geojson")
#' income_2022 <- wien_get_income(2022, poi)
#'
#' # Get income data for 2015 with a slower crawl speed
#' income_2015 <- wien_get_income(2015, sleep_ms = 300)
#' }
#'
#' @export
wien_get_income <- function(year, poi = wien_income_poi, sleep_ms = 100, download_dir = NULL, verbose = TRUE) {
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

    if (!is.null(download_dir) && !dir.exists(download_dir)) {
        stop("download_dir does not exist: ", download_dir)
    }

    BUFFER <- 1 # metres around each pole of inaccessibility
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
        VIEWPARAMS = glue::glue("YEAR:{year}-10-31;GT:v_pers;V1:geseink_mean;V2:geseink_sum;V1_ABS:geseink_sum;GEN:100;V2FILTER:-1;WIENFLAG:23;"),
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

    collected_features <- list()
    seen_ids <- character(0)

    if (verbose) {
        message(glue::glue("\nStarting Vienna income scrape for year {year} ({total} Zählbezirke)..."))
    }

    for (i in seq_len(nrow(poi))) {
        zgeb <- poi$ZGEB[i]
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
                    if (!is.null(feat_id) && !feat_id %in% seen_ids) {
                        seen_ids <- c(seen_ids, feat_id)
                        collected_features[[length(collected_features) + 1]] <- feat
                        new_count <- new_count + 1
                    }
                }

                if (new_count > 0 && !is.null(download_dir)) {
                    out_path <- file.path(download_dir, sprintf("wien_income_%d.geojson", year))
                    writeLines(
                        jsonlite::toJSON(
                            list(type = "FeatureCollection", features = collected_features),
                            auto_unbox = TRUE
                        ),
                        out_path
                    )
                }

                if (verbose) {
                    if (new_count > 0) {
                        message(sprintf("[%d/%d] ZGEB %s: %d new feature(s). Total: %d", i, total, zgeb, new_count, length(seen_ids)))
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

    if (length(collected_features) == 0) {
        message("No features collected.")
        return(NULL)
    }

    if (verbose) {
        message(glue::glue("\nDone! Collected {length(collected_features)} features for year {year}."))
    }

    geojson_str <- jsonlite::toJSON(
        list(type = "FeatureCollection", features = collected_features),
        auto_unbox = TRUE
    )

    if (!is.null(download_dir)) {
        out_path <- file.path(download_dir, sprintf("wien_income_%d.geojson", year))
        if (verbose) message("GeoJSON saved to: ", out_path)
        raw_sf <- sf::st_read(out_path, quiet = TRUE)
    } else {
        tmp <- tempfile(fileext = ".geojson")
        on.exit(unlink(tmp), add = TRUE)
        writeLines(geojson_str, tmp)
        raw_sf <- sf::st_read(tmp, quiet = TRUE)
    }

    raw_sf |>
        sf::st_drop_geometry() |>
        dplyr::select(-id) |>
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
        dplyr::ungroup()
}
