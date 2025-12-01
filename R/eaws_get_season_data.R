#' Get EAWS Avalanche Fatality Data for a Season
#'
#' Fetches avalanche fatality data from avalanches.org for a specific season.
#' Handles different data formats for seasons before and after 2017.
#'
#' @param season Integer or character. The starting year of the season (e.g., 2020 for the 2020-2021 season).
#' @return A data frame containing the avalanche fatality data. Structure varies slightly between pre- and post-2017 data.
#' @export
#'
#' @importFrom httr GET content http_status http_type
#' @importFrom jsonlite fromJSON
#' @importFrom xml2 read_xml xml_find_first xml_text xml_find_all
#' @importFrom dplyr map_dfr bind_rows mutate select group_by summarise
#' @importFrom purrr map_dfr map_int map map_chr
#' @importFrom tibble tibble
#' @importFrom rvest read_html html_node html_text
#' @importFrom methods is
#'
#' @examples
#' \dontrun{
#' # Get data for 2020 (modern format)
#' data_2020 <- eaws_get_season_data(2020)
#'
#' # Get data for 2009 (aggregated format)
#' data_2009 <- eaws_get_season_data(2009)
#' }
eaws_get_season_data <- function(season) {
    season <- as.integer(season)

    # Construct the URL for the API request
    url <- paste0(
        "https://www.avalanches.org/wp-content/plugins/eaws-fatalities/ajax/get.php?season=",
        season
    )

    # Make the GET request
    response <- httr::GET(url)

    # Check if the request was successful
    if (httr::http_status(response)$category != "Success") {
        stop(
            "Failed to fetch data from the API. Status code: ",
            httr::http_status(response)$reason
        )
    }

    # Parse the JSON content
    content_text <- httr::content(response, "text", encoding = "UTF-8")
    # Flatten=TRUE because the API seems to return a structure that parses into a flat DF with flatten=TRUE,
    # or at least consistent column names as seen in user output.
    season_data <- jsonlite::fromJSON(content_text, flatten = TRUE)

    if (length(season_data) == 0 || nrow(season_data) == 0) {
        message("No data found for season ", season)
        return(NULL)
    }

    # Determine which processing function to use based on the year
    if (season >= 2017) {
        message("Using post-2017 data processing.")
        return(.eaws_process_post_2017(season_data))
    } else {
        message("Using pre-2017 data processing.")
        return(.eaws_process_pre_2017(season_data))
    }
}

#' @keywords internal
.eaws_parse_caaml_xml <- function(url) {
    # Initialize result list with NAs
    res <- list(
        fatalities = NA_integer_,
        country = NA_character_,
        elevation = NA_real_,
        aspect = NA_character_,
        slope_angle = NA_real_,
        dead = NA_integer_,
        caught = NA_integer_,
        buried = NA_integer_,
        injured = NA_integer_,
        group_size = NA_integer_,
        av_type = NA_character_,
        av_size_destr = NA_real_,
        comment = NA_character_,
        group_activity = NA_character_,
        travel_mode = NA_character_
    )

    if (is.null(url) || is.na(url)) {
        return(res)
    }

    # Add a tryCatch to handle potential errors with fetching or parsing
    tryCatch(
        {
            response <- httr::GET(url)
            if (
                httr::http_type(response) %in% c("application/xml", "text/xml")
            ) {
                # Parse XML
                xml_content <- httr::content(
                    response,
                    "parsed",
                    encoding = "UTF-8"
                )

                # Helper to safe extract text
                get_val <- function(xpath, as_type = as.character) {
                    node <- xml2::xml_find_first(xml_content, xpath)
                    if (!is.na(node)) as_type(xml2::xml_text(node)) else NA
                }

                # --- Basic Details ---
                res$fatalities <- get_val(
                    ".//*[local-name()='numFatal']",
                    as.integer
                )
                res$dead <- res$fatalities # Alias
                res$country <- get_val(".//*[local-name()='country']")

                # --- Incident Details ---
                res$comment <- get_val(".//*[local-name()='comment']")
                res$group_activity <- get_val(
                    ".//*[local-name()='groupActivity']"
                )
                res$travel_mode <- get_val(".//*[local-name()='travelMode']")

                # --- Terrain Details ---
                res$elevation <- get_val(
                    ".//*[local-name()='validElevation']//*[local-name()='position']",
                    as.numeric
                )
                res$aspect <- get_val(
                    ".//*[local-name()='validAspect']//*[local-name()='position']"
                )
                res$slope_angle <- get_val(
                    ".//*[local-name()='validSlopeAngle']//*[local-name()='position']",
                    as.numeric
                )

                # --- Incident Stats ---
                res$caught <- get_val(
                    ".//*[local-name()='numCaughtOnly']",
                    as.integer
                )
                # CAAML v5 often distinguishes caught vs buried. Usually caught = caught_only + buried?
                # Or numCaughtOnly means caught but NOT buried? CAAML specs vary.
                # We map what is available.
                res$buried <- get_val(
                    ".//*[local-name()='numBuried']",
                    as.integer
                ) # Might not exist in all profiles
                res$injured <- get_val(
                    ".//*[local-name()='numInjuredOnly']",
                    as.integer
                )
                res$group_size <- get_val(
                    ".//*[local-name()='groupSize']",
                    as.integer
                )

                # --- Avalanche Details ---
                # avType often in obsLinks/AvObs/avObsResultsOf/AvObsMeasurements/avType
                # There can be multiple avTypes (e.g. A, S). We concatenate them.
                av_types <- xml2::xml_find_all(
                    xml_content,
                    ".//*[local-name()='avType']"
                )
                if (length(av_types) > 0) {
                    res$av_type <- paste(
                        xml2::xml_text(av_types),
                        collapse = ", "
                    )
                }

                res$av_size_destr <- get_val(
                    ".//*[local-name()='avSizeDestr']",
                    as.numeric
                )
            }
            return(res)
        },
        error = function(e) {
            return(res)
        }
    )
}

#' @keywords internal
.eaws_process_post_2017 <- function(season_data) {
    # season_data is a flattened data frame.
    # Columns typically: geometry.type, geometry.coordinates, properties.id, properties.date, properties.location, properties.caaml-url, properties.html

    # Parse coordinates
    lats <- numeric(nrow(season_data))
    lons <- numeric(nrow(season_data))

    # Check if geometry.coordinates exists
    if ("geometry.coordinates" %in% names(season_data)) {
        coords_raw <- season_data$geometry.coordinates

        # Function to parse single coordinate string or vector
        parse_coord <- function(x) {
            # Handle NULL or empty
            if (is.null(x) || length(x) == 0) {
                return(c(NA, NA))
            }

            # If it's a vector of length > 1 (e.g. numeric vector from JSON array), treat as coords
            if (length(x) >= 2 && (is.numeric(x) || is.integer(x))) {
                # Check for 0,0 which implies missing in some datasets
                if (all(x == 0)) {
                    return(c(NA, NA))
                }
                return(x[1:2])
            }

            # If it's a single string, check for comma separation or "NULL"
            if (length(x) == 1) {
                if (is.na(x)) {
                    return(c(NA, NA))
                }
                if (is.character(x)) {
                    if (x == "NULL" || x == "0, 0") {
                        return(c(NA, NA))
                    }
                    if (grepl(",", x)) {
                        parts <- as.numeric(trimws(strsplit(x, ",")[[1]]))
                        if (length(parts) >= 2) return(parts[1:2])
                    }
                }
            }

            return(c(NA, NA))
        }

        parsed_coords <- do.call(rbind, lapply(coords_raw, parse_coord))
        lats <- parsed_coords[, 1]
        lons <- parsed_coords[, 2]
    }

    # Fetch comprehensive details from XML
    # This uses the new parser
    xml_data_list <- purrr::map(
        season_data$`properties.caaml-url`,
        .eaws_parse_caaml_xml
    )

    # Extract vectors
    # Safely extract fields from the list of lists
    extract_field <- function(lst, field, default_val) {
        purrr::map_vec(lst, function(x) {
            if (is.null(x[[field]])) default_val else x[[field]]
        })
    }

    fatalities <- extract_field(xml_data_list, "fatalities", NA_integer_)
    countries <- extract_field(xml_data_list, "country", NA_character_)
    elevations <- extract_field(xml_data_list, "elevation", NA_real_)
    aspects <- extract_field(xml_data_list, "aspect", NA_character_)
    slopes <- extract_field(xml_data_list, "slope_angle", NA_real_)
    caught <- extract_field(xml_data_list, "caught", NA_integer_)
    injured <- extract_field(xml_data_list, "injured", NA_integer_)
    group_sizes <- extract_field(xml_data_list, "group_size", NA_integer_)
    av_types <- extract_field(xml_data_list, "av_type", NA_character_)
    comments <- extract_field(xml_data_list, "comment", NA_character_)
    group_activities <- extract_field(
        xml_data_list,
        "group_activity",
        NA_character_
    )
    travel_modes <- extract_field(xml_data_list, "travel_mode", NA_character_)

    # Parse dates
    dates <- as.POSIXct(
        season_data$`properties.date`,
        format = "%Y-%m-%d %H:%M:%S",
        tz = "UTC"
    )

    # Construct result tibble
    tibble::tibble(
        id = as.character(season_data$`properties.id`),
        date = dates,
        location = season_data$`properties.location`,
        country = countries,
        latitude = lats,
        longitude = lons,
        fatalities = fatalities,
        elevation = elevations,
        aspect = aspects,
        slope_angle = slopes,
        caught = caught,
        injured = injured,
        group_size = group_sizes,
        av_type = av_types,
        comment = comments,
        group_activity = group_activities,
        travel_mode = travel_modes,
        caaml_url = season_data$`properties.caaml-url`
    )
}

#' @keywords internal
.eaws_process_pre_2017 <- function(season_data) {
    # season_data is a flattened data frame.
    # Similar structure but often NULL coordinates.

    # Check for geometry.coordinates
    lats <- numeric(nrow(season_data))
    lons <- numeric(nrow(season_data))
    is_agg <- rep(TRUE, nrow(season_data))

    if ("geometry.coordinates" %in% names(season_data)) {
        coords_raw <- season_data$geometry.coordinates

        parse_coord_pre <- function(x) {
            # Handle NULL or empty
            if (is.null(x) || length(x) == 0) {
                return(c(NA, NA))
            }

            # If it's a vector of length > 1
            if (length(x) >= 2 && (is.numeric(x) || is.integer(x))) {
                if (all(x == 0)) {
                    return(c(NA, NA))
                }
                return(x[1:2])
            }

            # If it's a single element
            if (length(x) == 1) {
                if (is.na(x)) {
                    return(c(NA, NA))
                }
                if (is.character(x)) {
                    if (x == "NULL" || x == "0, 0") {
                        return(c(NA, NA))
                    }
                    if (grepl(",", x)) {
                        parts <- as.numeric(trimws(strsplit(x, ",")[[1]]))
                        if (length(parts) >= 2 && !all(parts == 0)) {
                            return(parts[1:2])
                        }
                    }
                }
            }
            return(c(NA, NA))
        }

        parsed_coords <- do.call(rbind, lapply(coords_raw, parse_coord_pre))
        lats <- parsed_coords[, 1]
        lons <- parsed_coords[, 2]
        is_agg <- is.na(lats) # If no coords, likely aggregated record
    }

    # Fetch comprehensive details from XML
    xml_data_list <- purrr::map(
        season_data$`properties.caaml-url`,
        .eaws_parse_caaml_xml
    )

    extract_field <- function(lst, field, default_val) {
        purrr::map_vec(lst, function(x) {
            if (is.null(x[[field]])) default_val else x[[field]]
        })
    }

    fatalities <- extract_field(xml_data_list, "fatalities", NA_integer_)
    countries <- extract_field(xml_data_list, "country", NA_character_)
    elevations <- extract_field(xml_data_list, "elevation", NA_real_)
    aspects <- extract_field(xml_data_list, "aspect", NA_character_)
    slopes <- extract_field(xml_data_list, "slope_angle", NA_real_)
    av_types <- extract_field(xml_data_list, "av_type", NA_character_)
    comments <- extract_field(xml_data_list, "comment", NA_character_)
    xml_activities <- extract_field(
        xml_data_list,
        "group_activity",
        NA_character_
    )
    travel_modes <- extract_field(xml_data_list, "travel_mode", NA_character_)

    # Parse Group Activity from HTML
    html_activities <- purrr::map_chr(
        season_data$`properties.html`,
        function(html) {
            if (is.null(html) || is.na(html)) {
                return(NA_character_)
            }
            val <- NA_character_
            tryCatch(
                {
                    frag <- rvest::read_html(html)
                    # Xpath for Group Activity
                    node <- rvest::html_node(
                        frag,
                        xpath = "//div[contains(., 'Group Activity')]/span"
                    )
                    if (!is.na(node)) val <- rvest::html_text(node)
                },
                error = function(e) {}
            )
            return(val)
        }
    )

    # Prioritize XML activity, fall back to HTML
    activities <- ifelse(
        !is.na(xml_activities),
        xml_activities,
        html_activities
    )

    dates <- as.Date(season_data$`properties.date`)

    tibble::tibble(
        id = as.character(season_data$`properties.id`),
        date = dates,
        country = countries,
        group_activity = activities,
        comment = comments,
        travel_mode = travel_modes,
        fatalities = fatalities,
        elevation = elevations,
        aspect = aspects,
        slope_angle = slopes,
        av_type = av_types,
        year = format(dates, "%Y"),
        latitude = lats,
        longitude = lons,
        is_aggregated = is_agg
    )
}
