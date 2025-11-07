#' Create opposing LAEA projections and clipping masks for world maps
#'
#' This function generates two opposing Lambert Azimuthal Equal-Area (LAEA)
#' projections and corresponding clipping masks. This is useful for creating
#' global maps for mobile devices, where two hemispheres are stacked to optimize
#' screen space and reduce distortion.
#'
#' @param lon A numeric value specifying the longitude for the center of the
#'   "front" hemisphere.
#' @param lat A numeric value specifying the latitude for the center of the
#'   "front" hemisphere.
#'
#' @return A list containing the following elements:
#'   \describe{
#'     \item{\code{front_proj}}{The proj4string for the front hemisphere.}
#'     \item{\code{back_proj}}{The proj4string for the back (antipodal) hemisphere.}
#'     \item{\code{front_clip}}{An 'sf' polygon object for clipping the front hemisphere.}
#'     \item{\code{back_clip}}{An 'sf' polygon object for clipping the back hemisphere.}
#'   }
#' @export
#'
#' @examples
#' \dontrun{
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   projections <- create_clipped_laea(lon = 10, lat = 50)
#'   print(projections$front_proj)
#'   print(projections$back_proj)
#'   # To see the clipping polygon
#'   # plot(projections$front_clip)
#' }
#' }
dav_create_clipped_laea_projections <- function(lon, lat) {
    if (!requireNamespace("sf", quietly = TRUE)) {
        stop(
            "Package 'sf' is required to run this function. Please install it with install.packages('sf')."
        )
    }

    # 1. Define proj4string for the front hemisphere
    front_proj <- paste0(
        "+proj=laea +lat_0=",
        lat,
        " +lon_0=",
        lon,
        " +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
    )

    # 2. Define proj4string for the back hemisphere (antipodal)
    back_lon <- ifelse(lon < 0, lon + 180, lon - 180)
    back_lat <- -lat
    back_proj <- paste0(
        "+proj=laea +lat_0=",
        back_lat,
        " +lon_0=",
        back_lon,
        " +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
    )

    # 3. Create clipping shapes
    # For a LAEA projection, a hemisphere is projected onto a circle.
    # The radius of this circle is sqrt(2) * R, where R is the radius of the Earth.
    # We use the semi-major axis of the WGS84 ellipsoid.
    earth_radius <- 6378137
    clip_radius <- earth_radius * sqrt(2)

    # Create a point at the origin (0,0) in the projected CRS and buffer it.
    # nQuadSegs is used to create a smoother circle.
    origin_pt <- sf::st_point(c(0, 0))

    # Front clipping polygon
    front_clip_sfc <- sf::st_sfc(origin_pt, crs = front_proj)
    front_clip <- sf::st_buffer(
        front_clip_sfc,
        dist = clip_radius,
        nQuadSegs = 150
    )

    # Back clipping polygon
    back_clip_sfc <- sf::st_sfc(origin_pt, crs = back_proj)
    back_clip <- sf::st_buffer(
        back_clip_sfc,
        dist = clip_radius,
        nQuadSegs = 50
    )

    # 4. Return results in a list
    return(
        list(
            front_proj = front_proj,
            back_proj = back_proj,
            front_clip = front_clip,
            back_clip = back_clip
        )
    )
}
