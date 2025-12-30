#' Download Geodata from UN OCHA
#'
#' Downloads geodata layers from the UN OCHA ArcGIS FeatureServer based on keywords.
#' Handles large layers by chunking requests using object IDs.
#'
#' @param keywords Character vector. Keywords to filter services/layers (case-insensitive).
#' @param output_dir Character. Directory to save downloaded GeoJSON files.
#' @param large_layer_threshold Integer. Threshold for number of features to consider a layer "large".
#'   If a layer exceeds this, the user is prompted (if interactive) or it follows `download_large`.
#' @param download_large Logical. If `TRUE`, automatically downloads large layers without prompting.
#'   If `FALSE` (default), asks in interactive mode or skips in non-interactive mode.
#' @param crs Character or Integer. CRS for output coordinates (default "4326").
#'
#' @return Invisible list of file paths to downloaded files.
#' @export
#'
#' @importFrom httr GET content status_code
#' @importFrom sf read_sf st_write
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning cli_progress_bar cli_progress_update
#' @importFrom utils askYesNo
un_ocha_download_geodata <- function(
    keywords = c(
        "Obstacle",
        "Barrier",
        "Checkpoint",
        "Road",
        "Palestine",
        "Gaza",
        "West Bank",
        "Crossing",
        "Fence",
        "Gate"
    ),
    output_dir = "downloads_geodata",
    large_layer_threshold = 100000,
    download_large = FALSE,
    crs = "4326"
) {
    # Ensure output directory exists
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE)
    }

    base_url <- "https://gis.unocha.org/server/rest/services/Hosted"

    cli::cli_alert_info("Fetching service list from UN OCHA...")

    # 1. Get List of Services
    resp <- tryCatch(
        httr::GET(base_url, query = list(f = "json")),
        error = function(e) {
            cli::cli_alert_danger(
                "Failed to connect to UN OCHA server: {e$message}"
            )
            return(NULL)
        }
    )

    if (is.null(resp) || httr::status_code(resp) != 200) {
        cli::cli_alert_danger("Failed to retrieve service list.")
        return(invisible(NULL))
    }

    catalog <- httr::content(resp, as = "parsed", type = "application/json")
    services <- catalog$services

    if (is.null(services)) {
        cli::cli_alert_warning("No services found.")
        return(invisible(NULL))
    }

    downloaded_files <- c()

    # 2. Iterate Services
    for (service in services) {
        s_name <- service$name
        s_type <- service$type

        # Filter by Keyword
        if (
            !any(sapply(keywords, function(k) {
                grepl(k, s_name, ignore.case = TRUE)
            }))
        ) {
            next
        }

        if (s_type != "FeatureServer") {
            next
        }

        clean_s_name <- gsub("Hosted/", "", s_name)
        service_url <- sprintf(
            "https://gis.unocha.org/server/rest/services/%s/FeatureServer",
            s_name
        )

        # 3. Get Layers inside
        l_resp <- tryCatch(
            httr::GET(service_url, query = list(f = "json")),
            error = function(e) NULL
        )

        if (is.null(l_resp) || httr::status_code(l_resp) != 200) {
            next
        }

        l_data <- httr::content(
            l_resp,
            as = "parsed",
            type = "application/json"
        )

        if (is.null(l_data$layers)) {
            next
        }

        for (layer in l_data$layers) {
            l_name <- layer$name
            l_id <- layer$id
            full_layer_url <- paste0(service_url, "/", l_id)

            cli::cli_alert_info("Checking: [{clean_s_name}] -> {l_name}")

            # 4. Check Size First (get IDs)
            ids_resp <- tryCatch(
                httr::GET(
                    paste0(full_layer_url, "/query"),
                    query = list(
                        where = "1=1",
                        returnIdsOnly = "true",
                        f = "json"
                    )
                ),
                error = function(e) NULL
            )

            ids <- NULL
            total_count <- 0
            should_download <- FALSE

            if (!is.null(ids_resp) && httr::status_code(ids_resp) == 200) {
                ids_data <- httr::content(
                    ids_resp,
                    as = "parsed",
                    type = "application/json"
                )
                if (!is.null(ids_data$objectIds)) {
                    ids <- unlist(ids_data$objectIds)
                    total_count <- length(ids)
                }
            }

            if (total_count == 0 && is.null(ids)) {
                # Fallback to simple download if IDs fetch failed or unsupported,
                # but if we got a valid response with 0 IDs, it's empty.
                # Actually if ids is NULL, maybe ID query failed.
                # Python script says: "Could not determine size".
                cli::cli_alert_warning("Could not determine layer size.")
                if (download_large) {
                    should_download <- TRUE
                } else if (interactive()) {
                    should_download <- utils::askYesNo("Download anyway?")
                    if (is.na(should_download)) should_download <- FALSE
                }
            } else if (total_count == 0) {
                cli::cli_alert_info("Empty layer. Skipping.")
                next
            } else {
                # We have a count
                if (total_count > large_layer_threshold) {
                    cli::cli_alert_warning(
                        "LARGE LAYER DETECTED: {total_count} features."
                    )
                    if (download_large) {
                        should_download <- TRUE
                    } else if (interactive()) {
                        should_download <- utils::askYesNo(paste0(
                            "Download ",
                            total_count,
                            " features?"
                        ))
                        if (is.na(should_download)) should_download <- FALSE
                    } else {
                        cli::cli_alert_info(
                            "Skipping large layer (non-interactive mode)."
                        )
                    }
                } else {
                    cli::cli_alert_info(
                        "Size: {total_count} features. Auto-downloading..."
                    )
                    should_download <- TRUE
                }
            }

            if (should_download) {
                # 5. Execute Download
                final_sf <- NULL

                if (!is.null(ids) && length(ids) > 0) {
                    # Chunked Download
                    chunk_size <- 1000
                    # Split IDs into chunks
                    id_chunks <- split(
                        ids,
                        ceiling(seq_along(ids) / chunk_size)
                    )

                    cli::cli_progress_bar(
                        "Downloading chunks",
                        total = length(id_chunks)
                    )

                    sf_list <- list()

                    for (i in seq_along(id_chunks)) {
                        chunk_ids <- id_chunks[[i]]
                        id_string <- paste(chunk_ids, collapse = ",")

                        chunk_params <- list(
                            objectIds = id_string,
                            outFields = "*",
                            f = "geojson",
                            outSR = crs
                        )

                        r_chunk <- tryCatch(
                            httr::GET(
                                paste0(full_layer_url, "/query"),
                                query = chunk_params
                            ),
                            error = function(e) NULL
                        )

                        if (
                            !is.null(r_chunk) &&
                                httr::status_code(r_chunk) == 200
                        ) {
                            # Parse GeoJSON to sf
                            # sf::read_sf can take the text response
                            chunk_text <- httr::content(
                                r_chunk,
                                as = "text",
                                encoding = "UTF-8"
                            )
                            # Skip if empty features (sometimes happens even with IDs?)
                            if (grepl('"features":\\s*\\[\\]', chunk_text)) {
                                cli::cli_progress_update()
                                next
                            }

                            chunk_sf <- tryCatch(
                                sf::read_sf(chunk_text, quiet = TRUE),
                                error = function(e) NULL
                            )

                            if (!is.null(chunk_sf)) {
                                sf_list[[length(sf_list) + 1]] <- chunk_sf
                            }
                        }
                        cli::cli_progress_update()
                    }

                    if (length(sf_list) > 0) {
                        # Combine all chunks
                        # Use dplyr::bind_rows or rbind? sf objects have a specific rbind method.
                        # do.call(rbind, ...) works for sf if columns match.
                        # If columns mismatch, bind_rows is safer but requires dplyr.
                        # Let's try do.call(rbind) first, catch error.
                        final_sf <- tryCatch(
                            do.call(rbind, sf_list),
                            error = function(e) {
                                # Fallback: align columns?
                                # For now, just return NULL or warning
                                cli::cli_alert_warning(
                                    "Failed to combine chunks: {e$message}"
                                )
                                return(NULL)
                            }
                        )
                    }
                } else {
                    # Simple Download
                    params <- list(
                        where = "1=1",
                        outFields = "*",
                        f = "geojson",
                        outSR = crs
                    )
                    r_simple <- tryCatch(
                        httr::GET(
                            paste0(full_layer_url, "/query"),
                            query = params
                        ),
                        error = function(e) NULL
                    )

                    if (
                        !is.null(r_simple) && httr::status_code(r_simple) == 200
                    ) {
                        simple_text <- httr::content(
                            r_simple,
                            as = "text",
                            encoding = "UTF-8"
                        )
                        final_sf <- tryCatch(
                            sf::read_sf(simple_text, quiet = TRUE),
                            error = function(e) NULL
                        )
                    }
                }

                # Save to file
                if (!is.null(final_sf) && nrow(final_sf) > 0) {
                    # Sanitize filename
                    safe_l_name <- gsub("[^a-zA-Z0-9_.-]", "_", l_name)
                    filename <- sprintf(
                        "%s___L%s_%s.geojson",
                        clean_s_name,
                        l_id,
                        safe_l_name
                    )
                    filepath <- file.path(output_dir, filename)

                    tryCatch(
                        {
                            sf::st_write(
                                final_sf,
                                filepath,
                                delete_dsn = TRUE,
                                quiet = TRUE
                            )
                            cli::cli_alert_success("Saved to: {filepath}")
                            downloaded_files <- c(downloaded_files, filepath)
                        },
                        error = function(e) {
                            cli::cli_alert_danger(
                                "Failed to save file: {e$message}"
                            )
                        }
                    )
                } else {
                    cli::cli_alert_warning(
                        "Download resulted in empty dataset."
                    )
                }
            }
        }
    }

    cli::cli_alert_success(
        "All done! Downloaded {length(downloaded_files)} files."
    )
    return(invisible(downloaded_files))
}
