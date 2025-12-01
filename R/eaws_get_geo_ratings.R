#' Get EAWS Microregions with Ratings
#'
#' This function downloads EAWS microregions from GitLab, fetches their names,
#' and joins them with avalanche ratings for a specific date.
#'
#' @param date Date object or character string (YYYY-MM-DD). Defaults to today's date.
#' @param output_dir Directory to save downloaded microregions. Defaults to "data_raw/microregions".
#' @param gitlab_token Optional GitLab private token.
#' @param language Language for microregion names (e.g., "de", "en"). Default is "de".
#' @param force_download Logical. If TRUE, re-downloads microregions even if they exist.
#'
#' @return An sf object containing microregions with names and ratings.
#' @export
#'
#' @importFrom sf read_sf st_make_valid st_as_sf write_sf
#' @importFrom dplyr bind_rows left_join rename mutate select
#' @importFrom tibble enframe
#' @importFrom tidyr separate_wider_delim
#' @importFrom purrr map keep safely pluck
#' @importFrom jsonlite fromJSON
#' @importFrom httr GET content status_code
#' @importFrom utils URLencode
#' @importFrom methods is
#'
eaws_get_geo_ratings <- function(
    date = Sys.Date(),
    output_dir = "data_raw/microregions",
    gitlab_token = NULL,
    language = "de",
    force_download = FALSE
    ) {
  # Ensure date is proper format
  date_str <- as.character(date)

  # 1. Download Microregions
  # We rely on the package's own gitlab_fetch_dir function
  # Assuming the user has this package installed or loaded.

  # Constants for EAWS repo
  gitlab_url <- "https://gitlab.com"
  project_id <- "eaws/eaws-regions"
  directory_path <- "public/micro-regions"
  branch <- "master"

  # Check if we need to download
  # We can check if the output directory is empty or force_download is TRUE
  # Construct the expected path where files land.
  # gitlab_fetch_dir appends the repo path to output_dir if we aren't careful,
  # but my implementation of gitlab_fetch_dir appends the relative path from the repo.
  # So if output_dir is "data_raw/microregions", and file is "public/micro-regions/AT-01.json",
  # it ends up at "data_raw/microregions/public/micro-regions/AT-01.json".

  target_path <- file.path(output_dir, directory_path)
  has_files <- dir.exists(target_path) &&
    length(list.files(
      target_path,
      pattern = "\\.json$",
      recursive = TRUE
    )) >
      0

  if (force_download || !has_files) {
    message("Downloading microregions from GitLab...")
    gitlab_fetch_dir(
      gitlab_url = gitlab_url,
      project_id = project_id,
      repo_path = directory_path,
      branch = branch,
      download = TRUE,
      output_dir = output_dir,
      private_token = gitlab_token
    )
  } else {
    message(
      "Microregions found locally. Skipping download (use force_download=TRUE to override)."
    )
  }

  # 2. Read Microregions
  message("Reading microregion geometries...")
  json_files <- list.files(
    target_path,
    pattern = ".*\\.json",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(json_files) == 0) {
    stop("No microregion JSON files found in ", target_path)
  }

  safe_read_sf <- purrr::safely(sf::read_sf)

  geo_list <- purrr::map(json_files, safe_read_sf)

  # Filter out errors
  geo_microregions <- geo_list %>%
    purrr::keep(~ is.null(.x$error)) %>%
    purrr::map("result") %>%
    purrr::map(sf::st_make_valid) %>%
    dplyr::bind_rows()

  # 3. Get Names
  message("Fetching microregion names...")
  names_url <- paste0(
    "https://gitlab.com/eaws/eaws-regions/-/raw/",
    branch,
    "/public/micro-regions_names/",
    language,
    ".json?ref_type=heads"
  )

  # Fetch names JSON
  # We can use jsonlite::fromJSON directly on URL usually, but let's be safe
  names_content <- tryCatch(
    {
      jsonlite::fromJSON(names_url)
    },
    error = function(e) {
      message("Warning: Could not fetch names from ", names_url)
      return(NULL)
    }
  )

  if (!is.null(names_content)) {
    d_names <- tibble::enframe(unlist(names_content))

    geo_microregions <- dplyr::left_join(
      geo_microregions,
      d_names,
      by = c("id" = "name")
    ) %>%
      dplyr::rename(label = value)
  } else {
    geo_microregions$label <- NA_character_
  }

  # 4. Get Ratings for Date
  message("Fetching ratings for ", date_str, "...")
  ratings_url <- paste0(
    "https://static.avalanche.report/eaws_bulletins/",
    date_str,
    "/",
    date_str,
    ".ratings.json"
  )

  response <- tryCatch(
    {
      httr::GET(ratings_url)
    },
    error = function(e) {
      message("Error: Could not fetch ratings from ", ratings_url)
      return(NULL)
    }
  )

  if (is.null(response) || httr::status_code(response) != 200) {
    warning(
      "No ratings found (HTTP ",
      if (!is.null(response)) httr::status_code(response) else "Error",
      "). Returning microregions without ratings."
    )
    return(geo_microregions)
  }

  # Process ratings based on user-provided snippet logic
  ratings_data <- tryCatch(
    {
      d_content <- httr::content(response, "parsed") %>%
        purrr::pluck("maxDangerRatings") %>%
        unlist() %>%
        tibble::enframe()

      if (nrow(d_content) > 0) {
        d_content_clean <- d_content %>%
          tidyr::separate_wider_delim(
            name,
            delim = ":",
            names = c("region_id", "info2", "info3"),
            too_few = "align_start",
            too_many = "merge"
          )
        # Rename value to rating
        d_content_clean <- dplyr::rename(
          d_content_clean,
          rating = value
        )
        d_content_clean
      } else {
        NULL
      }
    },
    error = function(e) {
      message("Error parsing ratings JSON: ", e$message)
      return(NULL)
    }
  )

  if (!is.null(ratings_data)) {

    joined_sf <- dplyr::full_join(
      geo_microregions,
      ratings_data,
      by = c("id" = "region_id"),
      relationship = "many-to-many"
    )

    return(joined_sf)
  } else {
    message("Warning: No valid ratings data extracted.")
    return(geo_microregions)
  }
}
