#' Weather Stations in Austrian Capitals
#'
#' A dataset containing information about selected weather stations
#' located in or representative of the nine Austrian federal state capitals.
#' This data is a filtered subset from the `davR::geosphere_get_stations()` function.
#'
#' @format A data frame (or `sf` object if geometry was kept) with X rows and Y variables:
#' \describe{
#'   \item{type}{Type of station (e.g., COMBINED, INDIVIDUAL)}
#'   \item{id}{Unique station identifier}
#'   \item{group_id}{Group identifier, if applicable}
#'   \item{name}{Name of the station}
#'   \item{state}{Austrian federal state (Bundesland)}
#'   \item{lat}{Latitude of the station}
#'   \item{lon}{Longitude of the station}
#'   \item{altitude}{Altitude of the station in meters}
#'   \item{valid_from}{Character string, start date of data validity (ISO 8601)}
#'   \item{valid_to}{Character string, end date of data validity (ISO 8601)}
#'   \item{has_sunshine}{Logical, whether the station measures sunshine duration}
#'   \item{has_global_radiation}{Logical, whether the station measures global radiation}
#'   \item{is_active}{Logical, whether the station is currently active}
#'   \item{geometry}{If it's an sf object, the POINT geometry}
#'   \item{...}{any other columns present}
#' }
#' @source Derived from `davR::geosphere_get_stations()`, filtered by specific station IDs
#' representing Austrian capitals. Data originally from GeoSphere Austria.
#' The selection of IDs can be found in `data-raw/geosphere_stations.R`.
#' @keywords datasets
#' @examples
#' \donttest{
#'   # Ensure the package is loaded if you're running this outside the package environment
#'   # library(yourpackagename)
#'
#'   data(geosphere_stations_in_capitals)
#'   head(geosphere_stations_in_capitals)
#'
#'   if (requireNamespace("dplyr", quietly = TRUE)) {
#'     dplyr::glimpse(geosphere_stations_in_capitals)
#'   }
#' }
"geosphere_stations_in_capitals"
