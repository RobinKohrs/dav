#' Poles of Inaccessibility for Vienna Zählbezirke
#'
#' A point dataset containing the pole of inaccessibility (the point furthest
#' from any boundary) for each Zählbezirk (census district) in Vienna.
#' Used by [statistik_get_zsp_einkommen()] to target WMS queries precisely inside each district.
#'
#' @format An `sf` object with one row per Zählbezirk and the following columns:
#' \describe{
#'   \item{ZGEB}{Character. The Zählgebiet code identifying the Zählbezirk.}
#'   \item{geometry}{Point geometry in EPSG:3857 (WGS 84 / Pseudo-Mercator).}
#' }
#' @source Computed from Statistik Austria Zählbezirk polygon boundaries.
#'
#' @seealso [statistik_get_zsp_einkommen()]
#'
#' @examples
#' plot(wien_income_poi["geometry"])
#'
#' @keywords datasets spatial sf Vienna Austria
#' @name wien_income_poi
NULL
