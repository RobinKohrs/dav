#' Centroids of Populated 1km INSPIRE Grid Cells in Austria
#'
#' An sf object containing the centroids of all populated 1km INSPIRE grid
#' cells in Austria, with the standard INSPIRE cell identifier. Used by
#' [statistik_get_1km_pop()] to query the Statistik Austria WMS service.
#'
#' @format An sf object with 85,705 rows and 2 columns:
#' \describe{
#'   \item{`cell_id`}{Character. INSPIRE 1km grid cell identifier in the form
#'     `"1kmN{northing}E{easting}"`, where northing and easting are the
#'     ETRS89-LAEA (EPSG:3035) coordinates of the cell's south-west corner
#'     in kilometres (integer).}
#'   \item{`geometry`}{Point geometry in EPSG:4326 (WGS84).}
#' }
#'
#' @source Derived from Statistik Austria population registry data.
#'   Cell centroids computed from the INSPIRE 1km grid for Austria
#'   (EPSG:3035, cell size 1000m). Only cells with at least one registered
#'   inhabitant are included.
#'
#' @seealso [statistik_get_1km_pop()]
"at_1km_centroids"
