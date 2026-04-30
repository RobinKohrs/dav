#' Poles of Inaccessibility / Centroids for Austria-wide Zählsprengel
#'
#' A point dataset containing one representative interior point
#' (pole of inaccessibility or centroid) per Zählsprengel across all of Austria.
#' Used by [statistik_get_zsp_einkommen()] to query the Statistik Austria WMS
#' service for income data at Zählsprengel level.
#'
#' @format An `sf` object with one row per Zählsprengel and the following columns:
#' \describe{
#'   \item{ZGEB}{Character. The Zählsprengel code (8-digit Kennziffer).}
#'   \item{geometry}{Point geometry in EPSG:3857 (WGS 84 / Pseudo-Mercator).}
#' }
#' @source Derived from Statistik Austria Zählsprengel polygon boundaries
#'   (original CRS: EPSG:31287 MGI / Austria Lambert).
#'
#' @seealso [statistik_get_zsp_einkommen()], [wien_income_poi]
#'
#' @examples
#' plot(at_income_poi["geometry"])
#'
#' @keywords datasets spatial sf Austria
#' @name at_income_poi
NULL
