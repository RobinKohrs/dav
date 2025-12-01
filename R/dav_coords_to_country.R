#' Get Country from Coordinates (Spatial)
#'
#' This function accepts latitude and longitude coordinates and returns the country name
#' using a spatial join with data from the `rnaturalearth` package.
#' It is vectorized and efficient for data frames.
#'
#' @param lat Numeric vector. Latitude.
#' @param lon Numeric vector. Longitude.
#'
#' @return A character vector containing the country names. NA where not found or coordinates are invalid.
#' @export
#'
#' @importFrom rnaturalearth ne_countries
#' @importFrom sf st_as_sf st_crs st_join st_set_crs st_intersects
#' @importFrom methods is
#'
#' @examples
#' \dontrun{
#' # Scalar usage
#' dav_coords_to_country(47.2, 11.4)
#'
#' # Vectorized usage in dplyr
#' library(dplyr)
#' df <- data.frame(lat = c(47.2, 48.8), lon = c(11.4, 2.3))
#' df %>% mutate(country = dav_coords_to_country(lat, lon))
#' }
dav_coords_to_country <- function(lat, lon) {
    # Ensure inputs are consistent
    if (length(lat) != length(lon)) {
        stop("Latitude and longitude vectors must have the same length.")
    }

    # Initialize result vector with NA
    result <- rep(NA_character_, length(lat))

    # Identify valid coordinates (non-NA)
    valid_idx <- which(!is.na(lat) & !is.na(lon))

    if (length(valid_idx) == 0) {
        return(result)
    }

    # Get world map (load once)
    world <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")

    # Create sf object for valid points
    # We use a temporary ID to map back if needed, though st_join preserves order of x usually
    pts_df <- data.frame(
        id = valid_idx,
        lon = lon[valid_idx],
        lat = lat[valid_idx]
    )

    pts_sf <- sf::st_as_sf(
        pts_df,
        coords = c("lon", "lat"),
        crs = 4326
    )

    # Spatial join
    # left=TRUE keeps all points, even those that don't match (they get NA attributes)
    # We use st_intersects as join predicate (default)
    joined <- sf::st_join(pts_sf, world, left = TRUE)

    # Handle potential duplicates: a point on a border might match two countries.
    # st_join can produce multiple rows for a single input point in that case.
    # We need to ensure 1:1 mapping for the valid_idx.
    # We take the first match for each ID.

    # Extract just the ID and the country (admin)
    joined_data <- joined[, c("id", "admin")]
    # Drop geometry to make it a plain data frame for processing
    sf::st_geometry(joined_data) <- NULL

    # De-duplicate by ID, taking the first non-NA or just first
    joined_data <- joined_data[!duplicated(joined_data$id), ]

    # Map back to results
    # valid_idx maps 1:1 to pts_df$id, and we have ensured joined_data has unique ids
    # Use match to be safe
    match_idx <- match(valid_idx, joined_data$id)
    result[valid_idx] <- joined_data$admin[match_idx]

    return(result)
}
