# Gaza West Bank Daily Casualties Data Functions
# ==============================================================================

#' Fetches the daily casualty reports for the West Bank
#'
#' This dataset provides a time series of killed and injured counts since October 7th, 2023.
#'
#' @details
#' \strong{Data Source:}
#' For West Bank data, the dataset depends on UN OCHA.
#'
#' There are two types of source material they provide that are used to build the time series:
#' \itemize{
#'   \item \strong{verified}: These are the ones independently verified by UN OCHA personnel and provided via their casualty database.
#'   \item \strong{flash-updates}: These are incidents reported to the UN, but not yet verified and they are the source of those root level values in the report object.
#' }
#'
#' Verified values will lag the ones that come from Flash Updates, so the field will be missing (optional) on more recent report dates, but generally continuous going back through older report dates once populated values are encountered.
#'
#' Flash Updates occasionally miss days and as of March 25 are only available for the West Bank on a weekly basis.
#'
#' \strong{Data Fields:}
#' Each daily report contains fields for:
#' \itemize{
#'   \item \code{report_date}: Date in YYYY-MM-DD format
#'   \item \code{verified.killed}: Killed persons on the given report date (verified)
#'   \item \code{verified.killed_cum}: Cumulative number of confirmed killed persons (verified)
#'   \item \code{verified.injured}: Injured persons on the given report date (verified)
#'   \item \code{verified.injured_cum}: Cumulative number of injured persons (verified)
#'   \item \code{verified.killed_children}: Number of children killed on the given report date (verified)
#'   \item \code{verified.killed_children_cum}: Cumulative number of children killed (verified)
#'   \item \code{verified.injured_children}: Number of children injured on the given report date (verified)
#'   \item \code{verified.injured_children_cum}: Cumulative number of children injured (verified)
#'   \item \code{killed_cum}: Same as verified.killed_cum but yet to be independently verified
#'   \item \code{killed_children_cum}: Same as verified.killed_children_cum but yet to be independently verified
#'   \item \code{injured_cum}: Same as verified.injured_cum but yet to be independently verified
#'   \item \code{injured_children_cum}: Same as verified.injured_children_cum but yet to be independently verified
#'   \item \code{settler_attacks_cum}: Cumulative number of attacks by settlers on civilians
#'   \item \code{flash_source}: Either "un" or "fill" (see March 25 update for more detail)
#' }
#'
#' @param format A string specifying the return format. Either "df" (default) to get
#'   a data frame from the CSV endpoint or "json" for the raw JSON data.
#' @param minified Logical. Whether to return minified JSON. Default is TRUE.
#'
#' @return A data frame or a list containing the daily casualty data for the West Bank.
#'
#' @examples
#' # Get as data frame (recommended)
#' west_bank_df = gaza_west_bank_casualties()
#'
#' # Get as JSON
#' west_bank_json = gaza_west_bank_casualties(format = "json")
#'
#' # Get unminified JSON
#' west_bank_full = gaza_west_bank_casualties(format = "json", minified = FALSE)
#'
#' @export
gaza_west_bank_casualties = function(format = "df", minified = TRUE) {
    if (format == "df") {
        url = paste0(BASE_URL, "/v2/west_bank_daily.csv")
        message(paste("Fetching West Bank daily casualties data from:", url))
        df = readr::read_csv(url, show_col_types = FALSE)

        # Convert report_date to Date
        df$report_date = as.Date(df$report_date)

        return(df)
    } else if (format == "json") {
        if (minified) {
            url = paste0(BASE_URL, "/v2/west_bank_daily.min.json")
        } else {
            url = paste0(BASE_URL, "/v2/west_bank_daily.json")
        }
        message(paste("Fetching West Bank daily casualties data from:", url))
        response = httr::GET(url)
        if (httr::status_code(response) == 200) {
            content = httr::content(response, "text", encoding = "UTF-8")
            return(jsonlite::fromJSON(content, flatten = TRUE))
        } else {
            stop(paste(
                "Failed to fetch West Bank daily casualties data. Status code:",
                httr::status_code(response)
            ))
        }
    } else {
        stop("Invalid format. Please use 'df' or 'json'.")
    }
}
