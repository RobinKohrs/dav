#' Polygons for Austria's 9 State Capitals
#'
#' Spatial polygon data for Austria’s 9 Landeshauptstädte (state capitals),
#' filtered from the official Statistik Austria municipal boundaries shapefile.
#'
#' @format An `sf` object with 9 rows and X columns (see below).
#' @source Statistik Austria: \url{https://data.statistik.gv.at/data/OGDEXT_GEM_1_STATISTIK_AUSTRIA_20250101.zip}
#' @details The data was filtered using the official municipality codes (GKZ) for the following capitals:
#' Wien, St. Pölten, Eisenstadt, Linz, Graz, Klagenfurt am Wörthersee, Salzburg, Innsbruck, Bregenz.
#'
#' @seealso The full shapefile was obtained from Statistik Austria's open data portal.
#'
#' @examples
#' plot(at_capitals_polys["geometry"])
#'
#' @keywords datasets spatial sf Austria
#' @name at_capitals_polys
NULL
