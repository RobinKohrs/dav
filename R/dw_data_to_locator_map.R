# R/dw_update_locator_map.R

#' Update a Datawrapper Locator Map with Markers
#'
#' This function uploads point, line, or area markers to a specific Datawrapper
#' locator map. It can process data from either a standard `data.frame` (for
#' points) or an `sf` object (for points, lines, or polygons).
#'
#' @details
#' The function constructs a JSON payload according to the Datawrapper API v3
#' specification and sends it via a `PUT` request, overwriting any existing
#' markers on the chart.
#'
#' For `sf` objects, the geometry type is automatically detected. `POINT` and
#' `MULTIPOINT` are treated as point markers, `LINESTRING` and `MULTILINESTRING`
#' as line markers, and `POLYGON` and `MULTIPOLYGON` as area markers.
#' The function will automatically transform coordinates to EPSG:4326 (WGS 84)
#' if they are in a different CRS.
#'
#' Many arguments (`title`, `tooltip_text`, `markerColor`, etc.) can be
#' provided either as a single static value (e.g., `markerColor = "#ff0000"`)
#' or as a string containing the name of a column in the input `data` (e.g.,
#' `markerColor = "color_column"`).
#'
#' @param data A `data.frame` or `sf` object containing the marker data.
#' @param chart_id The ID of the Datawrapper locator map to update.
#' @param api_key A Datawrapper API key. Defaults to the value of the
#'   `DATAWRAPPER_API_TOKEN` environment variable.
#' @param lon,lat Column names for longitude and latitude in `data` if it is a
#'   `data.frame`. Ignored for `sf` objects. Defaults to `"longitude"` and
#'   `"latitude"`.
#' @param title The marker title. Can be a static value or a column name.
#'   Defaults to an empty string. Supports basic HTML.
#' @param tooltip_text The text for the marker's tooltip. Can be a static value
#'   or a column name. Supports basic HTML.
#' @param ... Additional properties to be passed for each marker. See Datawrapper
#'   API documentation for available options (e.g., `anchor`, `offsetX`).
#'
#' @section Point Marker Properties:
#' These properties apply when creating point markers.
#' @param markerColor The marker fill color. Can be a static value or a column name.
#' @param scale The marker scale (size). Can be a static value or a column name.
#' @param icon_path SVG path for the marker icon. Defaults to a solid circle.
#'
#' @section Area/Line Marker Properties:
#' These properties apply when creating area or line markers.
#' @param fill_color The fill color for areas.
#' @param fill_opacity The fill opacity for areas (0-1).
#' @param stroke_color The stroke color for lines and area outlines.
#' @param stroke_width The stroke width.
#' @param stroke_opacity The stroke opacity (0-1).
#' @param stroke_dasharray The stroke dash pattern (e.g., "5,5").
#' @param exactShape For areas, if `TRUE`, renders the exact shape without simplification.
#'
#' @return Invisibly returns the `httr` response object.
#' @export
#' @md
#'
#' @importFrom httr PUT add_headers stop_for_status http_status content
#' @importFrom jsonlite toJSON
#' @importFrom sf st_is st_geometry_type st_transform st_crs st_coordinates st_geometry st_cast
#'
#' @examples
#' \dontrun{
#' # Ensure required packages are installed
#' # install.packages(c("sf", "httr", "jsonlite"))
#'
#' # --- Example 1: Using a data.frame for Points ---
#' df_points <- data.frame(
#'   name = c("Brandenburg Gate", "Reichstag Building"),
#'   longitude = c(13.3777, 13.3761),
#'   latitude = c(52.5163, 52.5186),
#'   size = c(1.5, 1.0),
#'   info = c("An 18th-century monument.", "Historic government building.")
#' )
#'
#' # Upload to Datawrapper, mapping columns to properties
#' dw_update_locator_map(
#'   data = df_points,
#'   chart_id = "YOUR_CHART_ID",
#'   lon = "longitude",
#'   lat = "latitude",
#'   title = "name",
#'   tooltip_text = "info",
#'   scale = "size",
#'   markerColor = "#c93e46"
#' )
#'
#' # --- Example 2: Using an sf object for Polygons (Areas) ---
#' # Create a sample sf polygon object
#' pol1 <- sf::st_polygon(list(rbind(c(0,0), c(1,0), c(1,1), c(0,1), c(0,0))))
#' pol2 <- sf::st_polygon(list(rbind(c(2,2), c(3,2), c(3,3), c(2,3), c(2,2))))
#' sf_areas <- sf::st_sf(
#'   name = c("Area 1", "Area 2"),
#'   fill_col = c("#15607acc", "#ff8000cc"),
#'   geometry = sf::st_sfc(pol1, pol2, crs = 4326)
#' )
#'
#' # Upload to Datawrapper
#' dw_update_locator_map(
#'   data = sf_areas,
#'   chart_id = "YOUR_CHART_ID",
#'   tooltip_text = "name",
#'   fill_color = "fill_col",
#'   stroke_width = 2
#' )
#' }
dw_update_locator_map <- function(data,
                                  chart_id,
                                  api_key = Sys.getenv("DATAWRAPPER_API_TOKEN"),
                                  lon = "longitude",
                                  lat = "latitude",
                                  title = "",
                                  tooltip_text = "",
                                  ...,
                                  # Point properties
                                  markerColor = "#c93e46",
                                  scale = 1,
                                  icon_path = "M1000 350a500 500 0 0 0-500-500 500 500 0 0 0-500 500 500 500 0 0 0 500 500 500 500 0 0 0 500-500z",
                                  # Area/Line properties
                                  fill_color = "#15607a",
                                  fill_opacity = 0.2,
                                  stroke_color = "#15607a",
                                  stroke_width = 1,
                                  stroke_opacity = 1,
                                  stroke_dasharray = "100000",
                                  exactShape = TRUE
) {

  # --- 1. Input Validation ---
  if (!requireNamespace("httr", quietly = TRUE)) stop("Package 'httr' is required.")
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Package 'jsonlite' is required.")

  if (chart_id == "" || is.null(chart_id)) stop("A valid chart_id is required.")
  if (api_key == "" || is.null(api_key)) stop("A Datawrapper API key is required. Set DATAWRAPPER_API_TOKEN or pass via api_key argument.")

  is_sf <- inherits(data, "sf")
  is_df <- inherits(data, "data.frame")

  if (!is_sf && !is_df) stop("Input 'data' must be a data.frame or an sf object.")

  if (is_sf && !requireNamespace("sf", quietly = TRUE)) stop("Package 'sf' is required for handling sf objects.")

  # --- 2. Data Preparation ---
  markers <- list()

  # Consolidate all properties into a single named list for easier access
  properties <- c(
    list(
      title = title,
      tooltip_text = tooltip_text,
      markerColor = markerColor,
      scale = scale,
      icon_path = icon_path,
      fill_color = fill_color,
      fill_opacity = fill_opacity,
      stroke_color = stroke_color,
      stroke_width = stroke_width,
      stroke_opacity = stroke_opacity,
      stroke_dasharray = stroke_dasharray,
      exactShape = exactShape
    ),
    list(...)
  )

  # --- 3. Marker Construction Loop ---
  for (i in 1:nrow(data)) {
    marker <- list()

    # Helper to resolve a property value (either static or from a column)
    get_prop <- function(prop_name) {
      val <- properties[[prop_name]]
      if (is.character(val) && length(val) == 1 && val %in% names(data)) {
        return(data[[val]][i])
      }
      return(val)
    }

    if (is_sf) {
      # --- Handle sf objects ---
      geom <- sf::st_geometry(data)[[i]]
      geom_type <- sf::st_geometry_type(geom, by_geometry = FALSE)

      # Ensure data is in WGS84 (EPSG:4326)
      if (sf::st_crs(data)$input != "EPSG:4326") {
        message("Transforming CRS to EPSG:4326 (WGS 84).")
        data <- sf::st_transform(data, 4326)
        geom <- sf::st_geometry(data)[[i]]
      }

      if (geom_type %in% c("POINT", "MULTIPOINT")) {
        marker$type <- "point"
        coords <- sf::st_coordinates(geom)
        marker$coordinates <- as.list(coords[1, 1:2]) # [lon, lat]
        marker$title <- get_prop("title")
        marker$tooltip <- list(text = as.character(get_prop("tooltip_text")))
        marker$markerColor <- get_prop("markerColor")
        marker$scale <- get_prop("scale")
        marker$icon <- list(path = get_prop("icon_path"), height = 700, width = 1000)

      } else if (geom_type %in% c("LINESTRING", "MULTILINESTRING")) {
        marker$type <- "line"
        # The unclass() trick gets coordinates into the right list structure for JSON
        coords <- unclass(sf::st_cast(geom, "MULTILINESTRING"))
        marker$feature <- list(type = "Feature", geometry = list(type = "MultiLineString", coordinates = coords))
        marker$title <- get_prop("title")
        marker$properties <- list(
          stroke = get_prop("stroke_color"),
          `stroke-width` = get_prop("stroke_width"),
          `stroke-opacity` = get_prop("stroke_opacity"),
          `stroke-dasharray` = get_prop("stroke_dasharray")
        )

      } else if (geom_type %in% c("POLYGON", "MULTIPOLYGON")) {
        marker$type <- "area"
        coords <- unclass(sf::st_cast(geom, "MULTIPOLYGON"))
        marker$feature <- list(type = "Feature", geometry = list(type = "MultiPolygon", coordinates = coords))
        marker$tooltip <- list(text = as.character(get_prop("tooltip_text")))
        marker$exactShape <- get_prop("exactShape")
        marker$properties <- list(
          fill = get_prop("fill_color"),
          `fill-opacity` = get_prop("fill_opacity"),
          stroke = get_prop("stroke_color"),
          `stroke-width` = get_prop("stroke_width"),
          `stroke-opacity` = get_prop("stroke_opacity")
        )

      } else {
        warning(paste("Unsupported geometry type:", geom_type, "for row", i, "- skipping."))
        next
      }

    } else {
      # --- Handle data.frame (assumed points) ---
      if (!all(c(lon, lat) %in% names(data))) {
        stop(paste0("Columns '", lon, "' and '", lat, "' not found in data.frame."))
      }
      marker$type <- "point"
      marker$coordinates <- list(data[[lon]][i], data[[lat]][i])
      marker$title <- get_prop("title")
      marker$tooltip <- list(text = as.character(get_prop("tooltip_text")))
      marker$markerColor <- get_prop("markerColor")
      marker$scale <- get_prop("scale")
      marker$icon <- list(path = get_prop("icon_path"), height = 700, width = 1000)
    }

    # Add any extra properties from ...
    extra_args <- properties[!names(properties) %in% c(
      "title", "tooltip_text", "markerColor", "scale", "icon_path",
      "fill_color", "fill_opacity", "stroke_color", "stroke_width",
      "stroke_opacity", "stroke_dasharray", "exactShape"
    )]

    if (length(extra_args) > 0) {
      for (arg_name in names(extra_args)) {
        marker[[arg_name]] <- get_prop(arg_name)
      }
    }

    markers[[length(markers) + 1]] <- marker
  }

  # --- 4. JSON Payload Creation ---
  payload <- list(markers = markers)
  json_payload <- jsonlite::toJSON(payload, auto_unbox = TRUE, pretty = FALSE)

  # --- 5. API Call ---
  url <- paste0("https://api.datawrapper.de/v3/charts/", chart_id, "/data")

  message(paste("Uploading", length(markers), "markers to chart", chart_id, "..."))

  response <- httr::PUT(
    url = url,
    httr::add_headers(
      Authorization = paste("Bearer", api_key),
      `Content-Type` = "application/json"
    ),
    body = json_payload,
    encode = "raw"
  )

  # --- 6. Handle Response ---
  httr::stop_for_status(
    response,
    task = paste(
      "upload markers to Datawrapper chart", chart_id,
      ".\nResponse:", httr::content(response, "text", encoding = "UTF-8")
    )
  )

  message("Successfully updated locator map.")
  invisible(response)
}
