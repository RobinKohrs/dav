# In R/data_shapes.R (or a similar file)

#' Get Austria Boundary Shape at Specified Resolution
#'
#' Retrieves the administrative boundary of Austria as an sf object,
#' using pre-packaged data derived from Eurostat/GISCO.
#'
#' The data is included within the package. Available resolutions correspond
#' to the GISCO distribution codes. See \url{https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units/countries}
#'
#' @param resolution Character string. The desired resolution code.
#'   Available options packaged are: "60" (1:60 Million) (low), "10" (1:10 milltion) (medium), "01" (1:1 Million) (high).
#'   Defaults to "10".
#'
#' @return An \code{\link[sf]{sf}} object representing the boundary of Austria
#'   at the specified resolution. Includes columns for name, ISO2 code, and geometry.
#' @export
#' @importFrom sf st_geometry
#'
#' @examples
#' \dontrun{ # Requires sf package to be fully functional
#'   if (requireNamespace("sf", quietly = TRUE)) {
#'     # Get default resolution (10)
#'     aut_shape_med = get_austria_shape()
#'     plot(sf::st_geometry(aut_shape_med), main = "Austria (10M)")
#'
#'     # Get high resolution
#'     aut_shape_high = get_austria_shape(resolution = "01")
#'     plot(sf::st_geometry(aut_shape_high), main = "Austria (01)", border = "blue")
#'
#'     # Get low resolution
#'     aut_shape_low = get_austria_shape(resolution = "60")
#'     plot(sf::st_geometry(aut_shape_low), main = "Austria (60)", border = "red")
#'   }
#' }
at_get_austria_poly = function(resolution = "10") {

  # Access the lazy-loaded data list object (available because it's in data/)
  # Using ::austria_shapes makes it explicit we expect this from our package
  shape_data = davR::austria_shapes
  # Alternative if function is guaranteed to be called only after pkg load:
  # shape_data = austria_shapes

  # Validate the requested resolution
  available_resolutions = names(shape_data)
  if (!resolution %in% available_resolutions) {
    stop(
      "Invalid resolution requested: '", resolution, "'.\n",
      "Available resolutions in this package are: ",
      paste(sapply(available_resolutions, function(x) paste0("'", x, "'")), collapse = ", ")
    )
  }

  # Select the shape object for the requested resolution
  selected_shape = shape_data[[resolution]]

  return(selected_shape)
}
