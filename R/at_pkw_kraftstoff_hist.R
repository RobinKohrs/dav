#' Historical Pkw-Neuzulassungen by Bundesland and Kraftstoffart (2006–2025)
#'
#' Monthly counts of new Pkw (passenger car) registrations in Austria,
#' broken down by Bundesland and fuel/drive type, covering January 2006 to
#' December 2025. The data were provided by Statistik Austria as a special
#' evaluation and are bundled in the package for offline access.
#'
#' Combine with the live data from [statistik_get_kraftstoff_timeseries()] to
#' extend the series through the current year.
#'
#' @format A tibble with 22,560 rows and 5 columns:
#' \describe{
#'   \item{`bundesland`}{Austrian state (`"Burgenland"`, ..., `"Wien"`,
#'     `"Österreich"` for the national total).}
#'   \item{`kraftstoffart`}{Fuel/drive type, e.g. `"Benzin"`, `"Diesel"`,
#'     `"Elektro"`, `"Benzin/Elektro (hybrid)"`, etc.}
#'   \item{`year`}{Integer year.}
#'   \item{`month`}{Integer month (1–12).}
#'   \item{`date`}{`Date`: first day of the month.}
#'   \item{`anzahl`}{Integer count of new registrations (`NA` = suppressed
#'     due to small cell size).}
#' }
#' @source Statistik Austria, special evaluation provided per request.
#'   License: CC BY 4.0.
"at_pkw_kraftstoff_hist"
