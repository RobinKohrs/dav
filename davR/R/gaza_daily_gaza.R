# Gaza Daily Casualties Data Functions
# ==============================================================================

#' Fetches the daily casualty reports for Gaza
#'
#' This dataset provides a time series of killed and injured counts since October 7th, 2023.
#'
#' @details
#' \strong{Data Source:}
#' There are four source values for daily casualty reports used to build the time series:
#' \itemize{
#'   \item \strong{mohtel}: Gaza's Ministry of Health Telegram channel (primary source)
#'   \item \strong{gmotel}: Gaza's Government Media Office Telegram channel
#'   \item \strong{unocha}: UN OCHA reports
#'   \item \strong{missing}: No official report was available for the given date
#' }
#'
#' The primary source is the Ministry of Health. The numbers they report only include those they can connect directly to an act of war. For example:
#'
#' "The Ministry of Health has a policy of recording only direct casualties of war, such as those caused by missile strikes or war-related injuries. There are other deaths indirectly caused by the war, but we do not add them to the list of martyrs. For example, children who die due to malnutrition, lack of care, or because their mothers gave birth under difficult conditions and carried them in poor health, resulting in the birth of an underdeveloped infant who dies after a few days or lacked proper feeding, these cases are documented but not recorded as martyrs."
#'
#' \strong{Extrapolated Fields:}
#' Since official numbers weren't always available, extrapolated fields (prefixed with "ext_") are provided using the following methodology:
#' \itemize{
#'   \item If the missing field was a cumulative one and we had an official report for a daily killed or injury count, we calculate the cumulative using the daily increment
#'   \item If the missing field was a daily increment and we had cumulative counts, we subtracted the reported cumulative count from the prior period for the missing daily count
#'   \item If we were missing both sets of numbers for a given reporting period we average the difference between surrounding periods
#' }
#'
#' \strong{Breakdown Interval:}
#' Since October 2023, Gaza officials were reporting specific breakdowns for people killed on a semi-regular basis. In 2024, the GMO reported these breakdowns on a weekly basis, and in August 2024 began reporting them about every 2 weeks. In January 2025 this form of reporting was reduced to about every month.
#'
#' \strong{Data Fields:}
#' Each daily report contains fields for:
#' \itemize{
#'   \item \code{report_date}: Date in YYYY-MM-DD format
#'   \item \code{report_source}: Source (mohtel, gmotel, unocha, or missing)
#'   \item \code{report_period}: Hours length of reporting period (24, 48, or 0)
#'   \item \code{killed}: Total killed persons for the given report date
#'   \item \code{killed_cum}: Cumulative number of killed persons to the report date
#'   \item \code{killed_children_cum}: Cumulative number of children killed
#'   \item \code{killed_women_cum}: Cumulative number of women killed
#'   \item \code{injured}: Injured persons on the given report date
#'   \item \code{injured_cum}: Cumulative number of injured persons
#'   \item \code{civdef_killed_cum}: Cumulative emergency services killed
#'   \item \code{med_killed_cum}: Cumulative medical personnel killed
#'   \item \code{press_killed_cum}: Cumulative journalists killed
#'   \item \code{famine_cum}: Cumulative adults & children killed by starvation
#'   \item \code{aid_seeker_killed_cum}: Cumulative people killed while seeking aid
#'   \item And many more fields with "ext_" prefixes for extrapolated values
#' }
#'
#' @param format A string specifying the return format. Either "df" (default) to get
#'   a data frame from the CSV endpoint or "json" for the raw JSON data.
#' @param minified Logical. Whether to return minified JSON. Default is TRUE.
#'
#' @return A data frame or a list containing the daily casualty data for Gaza.
#'
#' @examples
#' # Get as data frame (recommended)
#' daily_casualties_df = gaza_daily_casualties()
#'
#' # Get as JSON
#' daily_casualties_json = gaza_daily_casualties(format = "json")
#'
#' # Get unminified JSON
#' daily_casualties_full = gaza_daily_casualties(format = "json", minified = FALSE)
#'
#' @export
gaza_daily_casualties = function(format = "df", minified = TRUE) {
    if (format == "df") {
        url = paste0(BASE_URL, "/v2/casualties_daily.csv")
        message(paste("Fetching Gaza daily casualties data from:", url))
        df = readr::read_csv(url, show_col_types = FALSE)

        # Convert report_date to Date
        df$report_date = as.Date(df$report_date)

        return(df)
    } else if (format == "json") {
        if (minified) {
            url = paste0(BASE_URL, "/v2/casualties_daily.min.json")
        } else {
            url = paste0(BASE_URL, "/v2/casualties_daily.json")
        }
        message(paste("Fetching Gaza daily casualties data from:", url))
        response = httr::GET(url)
        if (httr::status_code(response) == 200) {
            content = httr::content(response, "text", encoding = "UTF-8")
            return(jsonlite::fromJSON(content, flatten = TRUE))
        } else {
            stop(paste(
                "Failed to fetch Gaza daily casualties data. Status code:",
                httr::status_code(response)
            ))
        }
    } else {
        stop("Invalid format. Please use 'df' or 'json'.")
    }
}
