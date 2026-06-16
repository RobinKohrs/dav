# Update a Datawrapper Locator Map with Markers

This function uploads point, line, or area markers to a specific
Datawrapper locator map. It can process data from either a standard
`data.frame` (for points) or an `sf` object (for points, lines, or
polygons).

## Usage

``` r
dw_update_locator_map(
  data,
  chart_id,
  api_key = Sys.getenv("DATAWRAPPER_API_TOKEN"),
  lon = "longitude",
  lat = "latitude",
  title = "",
  tooltip_text = "",
  ...,
  markerColor = "#c93e46",
  scale = 1,
  icon_path =
    "M1000 350a500 500 0 0 0-500-500 500 500 0 0 0-500 500 500 500 0 0 0 500 500 500 500 0 0 0 500-500z",
  fill_color = "#15607a",
  fill_opacity = 0.2,
  stroke_color = "#15607a",
  stroke_width = 1,
  stroke_opacity = 1,
  stroke_dasharray = "100000",
  exactShape = TRUE
)
```

## Arguments

- data:

  A `data.frame` or `sf` object containing the marker data.

- chart_id:

  The ID of the Datawrapper locator map to update.

- api_key:

  A Datawrapper API key. Defaults to the value of the
  `DATAWRAPPER_API_TOKEN` environment variable.

- lon, lat:

  Column names for longitude and latitude in `data` if it is a
  `data.frame`. Ignored for `sf` objects. Defaults to `"longitude"` and
  `"latitude"`.

- title:

  The marker title. Can be a static value or a column name. Defaults to
  an empty string. Supports basic HTML.

- tooltip_text:

  The text for the marker's tooltip. Can be a static value or a column
  name. Supports basic HTML.

- ...:

  Additional properties to be passed for each marker. See Datawrapper
  API documentation for available options (e.g., `anchor`, `offsetX`).

- markerColor:

  The marker fill color. Can be a static value or a column name.

- scale:

  The marker scale (size). Can be a static value or a column name.

- icon_path:

  SVG path for the marker icon. Defaults to a solid circle.

- fill_color:

  The fill color for areas.

- fill_opacity:

  The fill opacity for areas (0-1).

- stroke_color:

  The stroke color for lines and area outlines.

- stroke_width:

  The stroke width.

- stroke_opacity:

  The stroke opacity (0-1).

- stroke_dasharray:

  The stroke dash pattern (e.g., "5,5").

- exactShape:

  For areas, if `TRUE`, renders the exact shape without simplification.

## Value

Invisibly returns the `httr` response object.

## Details

The function constructs a JSON payload according to the Datawrapper API
v3 specification and sends it via a `PUT` request, overwriting any
existing markers on the chart.

For `sf` objects, the geometry type is automatically detected. `POINT`
and `MULTIPOINT` are treated as point markers, `LINESTRING` and
`MULTILINESTRING` as line markers, and `POLYGON` and `MULTIPOLYGON` as
area markers. The function will automatically transform coordinates to
EPSG:4326 (WGS 84) if they are in a different CRS.

Many arguments (`title`, `tooltip_text`, `markerColor`, etc.) can be
provided either as a single static value (e.g.,
`markerColor = "#ff0000"`) or as a string containing the name of a
column in the input `data` (e.g., `markerColor = "color_column"`).

## Point Marker Properties

These properties apply when creating point markers.

## Area/Line Marker Properties

These properties apply when creating area or line markers.

## Examples

``` r
if (FALSE) { # \dontrun{
# Ensure required packages are installed
# install.packages(c("sf", "httr", "jsonlite"))

# --- Example 1: Using a data.frame for Points ---
df_points <- data.frame(
  name = c("Brandenburg Gate", "Reichstag Building"),
  longitude = c(13.3777, 13.3761),
  latitude = c(52.5163, 52.5186),
  size = c(1.5, 1.0),
  info = c("An 18th-century monument.", "Historic government building.")
)

# Upload to Datawrapper, mapping columns to properties
dw_update_locator_map(
  data = df_points,
  chart_id = "YOUR_CHART_ID",
  lon = "longitude",
  lat = "latitude",
  title = "name",
  tooltip_text = "info",
  scale = "size",
  markerColor = "#c93e46"
)

# --- Example 2: Using an sf object for Polygons (Areas) ---
# Create a sample sf polygon object
pol1 <- sf::st_polygon(list(rbind(c(0,0), c(1,0), c(1,1), c(0,1), c(0,0))))
pol2 <- sf::st_polygon(list(rbind(c(2,2), c(3,2), c(3,3), c(2,3), c(2,2))))
sf_areas <- sf::st_sf(
  name = c("Area 1", "Area 2"),
  fill_col = c("#15607acc", "#ff8000cc"),
  geometry = sf::st_sfc(pol1, pol2, crs = 4326)
)

# Upload to Datawrapper
dw_update_locator_map(
  data = sf_areas,
  chart_id = "YOUR_CHART_ID",
  tooltip_text = "name",
  fill_color = "fill_col",
  stroke_width = 2
)
} # }
```
