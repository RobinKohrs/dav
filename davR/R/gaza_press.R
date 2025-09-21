# Gaza Press Killed Data Functions
# ==============================================================================

#' Fetches the list of journalists killed in Gaza
#'
#' @details
#' \strong{Data Source:}
#' The file is updated when a new list is released by Gaza's Government Media Office or when incremental updates about new individual incidents are received. These are sourced from the Ministry's Telegram Channel.
#'
#' The ministry has previously released photos of some of those killed, which can be retrieved in Arabic and English from their public Google Drive. As of writing, it includes photos for just over half of the list.
#'
#' \strong{Data Fields:}
#' Each record contains:
#' \itemize{
#'   \item \code{name}: Original Arabic name from the source list
#'   \item \code{name_en}: English name translation
#'   \item \code{notes}: Includes agency they worked for & available detail on how they were killed
#' }
#'
#' @param format A string specifying the return format. Either "df" (default) to get
#'   a data frame from the CSV endpoint or "json" for the raw JSON data.
#' @param minified Logical. Whether to return minified JSON. Default is TRUE.
#'
#' @return A data frame or a list containing the data.
#'
#' @examples
#' # Get as data frame (recommended)
#' press_df = gaza_press_killed()
#'
#' # Get as JSON
#' press_json = gaza_press_killed(format = "json")
#'
#' # Get unminified JSON
#' press_full = gaza_press_killed(format = "json", minified = FALSE)
#'
#' @export
gaza_press_killed = function(format = "df", minified = TRUE) {
    if (format == "df") {
        url = paste0(BASE_URL, "/v2/press_killed_in_gaza.csv")
        message(paste("Fetching press killed data from:", url))
        df = readr::read_csv(url, show_col_types = FALSE)
        return(df)
    } else if (format == "json") {
        if (minified) {
            url = paste0(BASE_URL, "/v2/press_killed_in_gaza.min.json")
        } else {
            url = paste0(BASE_URL, "/v2/press_killed_in_gaza.json")
        }
        message(paste("Fetching press killed data from:", url))
        response = httr::GET(url)
        if (httr::status_code(response) == 200) {
            content = httr::content(response, "text", encoding = "UTF-8")
            return(jsonlite::fromJSON(content, flatten = TRUE))
        } else {
            stop(paste(
                "Failed to fetch press killed data. Status code:",
                httr::status_code(response)
            ))
        }
    } else {
        stop("Invalid format. Please use 'df' or 'json'.")
    }
}
