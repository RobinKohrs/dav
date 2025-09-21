# Gaza Killed Data Functions
# ==============================================================================

#' Fetches the complete list of known individuals killed in Gaza
#'
#' This function retrieves the dataset of names of those killed in Gaza. The recommended
#' method is using the default `format = "df"`, which fetches the data page by page
#' to avoid long request times and potential timeouts with the full file.
#'
#' @details
#' \strong{Data Source and Updates:}
#' The file is updated when a new list is released by Gaza's Ministry of Health.
#'
#' This list incorporates the following releases from the Ministry of Health:
#' \itemize{
#'   \item \strong{First release} (January 5th, 2024): Hospitals reporting in the South and November 2nd 2023 for the North. Additionally, 21 records were included from an earlier release as noted in the February update.
#'   \item \strong{Second release} (March 29th, 2024): Included submissions from the public to the Ministry (i.e., families of those killed). Changes detailed in April 29th update.
#'   \item \strong{Third release} (April 30th, 2024): Released on May 5th from the Ministry. Changes detailed in June 26th update.
#'   \item \strong{Fourth release} (June 30th, 2024): Released on July 24th from the Ministry. Changes detailed in September 7th update.
#'   \item \strong{Fifth release} (August 31st, 2024): Released around September 15th by the Ministry. Changes detailed in September 21st update.
#'   \item \strong{Sixth release} (March 23rd, 2025): Released on the same day by the Ministry via Iraq Body Count. Changes detailed in May 11th update.
#'   \item \strong{Seventh release} (June 15th, 2025): Released on June 23rd from the Ministry via Iraq Body Count. Changes detailed in July 6th update.
#'   \item \strong{Eighth release} (July 15th, 2025): Released on July 16th from the Ministry via Iraq Body Count. Changes detailed in July 20th update.
#'   \item \strong{Ninth release} (July 31st, 2025): Released on August 4th from the Ministry via Iraq Body Count. Changes detailed in August 17th update.
#' }
#'
#' \strong{Data Limitations:}
#' In their initial January 2024 update, the Ministry indicated the following about the list:
#' \itemize{
#'   \item The missing persons and the bodies of those trapped under the rubble were not counted
#'   \item The unidentified people who arrived at hospitals were not counted
#'   \item The unidentified persons whose bodies were handed over by the occupation were not counted
#'   \item Those who were buried by their families without passing through hospitals were not counted
#'   \item The victims in Gaza and North Gaza were not counted after the date of stopping the information system in November
#' }
#'
#' The aggregate numbers in the Daily Casualties - Gaza dataset will necessarily diverge from this list due to the number of unidentified people.
#'
#' \strong{Data Fields:}
#' Each record contains:
#' \itemize{
#'   \item \code{name}: Original Arabic name from the source list
#'   \item \code{en_name}: English name translation
#'   \item \code{id}: Unique string identifier (format may change)
#'   \item \code{dob}: Date of birth in YYYY-MM-DD format, or empty string if not available
#'   \item \code{sex}: "m" for male or "f" for female
#'   \item \code{age}: Age as a number
#'   \item \code{source}: Source indicator - "h" (Ministry of Health), "c" (Public Submission), "j" (judicial or house committee), "u" (unknown)
#' }
#'
#' @param format A string specifying the format.
#'   \itemize{
#'     \item "df" (default): Fetches all pages sequentially and combines them into a single data frame. Most robust method.
#'     \item "csv": Downloads the complete dataset as a single CSV file and returns a data frame.
#'     \item "json": Downloads the complete dataset as a single minified JSON file.
#'     \item "page": Returns a specific page number (requires page parameter).
#'   }
#' @param page Integer. Page number (1-602). Only used when format = "page".
#' @param minified Logical. Whether to return minified JSON. Default is TRUE.
#' @param progress Logical. Whether to show progress bar for multi-page downloads. Default is TRUE.
#'
#' @return A data frame containing the list of names and associated details, or raw JSON content.
#'
#' @examples
#' # Get the data as a data frame by fetching all pages (recommended)
#' killed_df = gaza_killed()
#'
#' # Get the full dataset directly from the CSV endpoint
#' killed_from_csv = gaza_killed(format = "csv")
#'
#' # Get a specific page
#' page_1 = gaza_killed(format = "page", page = 1)
#'
#' # Get without progress bar
#' data = gaza_killed(progress = FALSE)
#'
#' @export
gaza_killed = function(
    format = "df",
    page = NULL,
    minified = TRUE,
    progress = TRUE
) {
    if (format == "df") {
        summary_data = gaza_summary_data()
        total_pages = summary_data$known_killed_in_gaza$pages

        if (is.null(total_pages)) {
            stop(
                "Could not determine the total number of pages from summary data."
            )
        }

        message(paste(
            "Fetching",
            total_pages,
            "pages of data. This may take a moment..."
        ))

        if (progress) {
            pb = utils::txtProgressBar(min = 0, max = total_pages, style = 3)
        }

        all_pages_list = list()
        for (page_num in 1:total_pages) {
            page_url = paste0(
                BASE_URL,
                "/v2/killed-in-gaza/page-",
                page_num,
                ".json"
            )
            response = httr::GET(page_url)
            if (httr::status_code(response) == 200) {
                content = httr::content(response, "text", encoding = "UTF-8")
                page_data = jsonlite::fromJSON(content, flatten = TRUE)
                all_pages_list[[page_num]] = page_data
                Sys.sleep(0.1) # Be considerate to the API server
            } else {
                warning(paste(
                    "Failed to fetch page",
                    page_num,
                    "- Status code:",
                    httr::status_code(response)
                ))
            }

            if (progress) {
                utils::setTxtProgressBar(pb, page_num)
            }
        }

        if (progress) {
            close(pb)
        }

        combined_df = do.call(rbind, all_pages_list)

        # Convert date of birth to Date if present
        if ("dob" %in% names(combined_df)) {
            combined_df$dob = as.Date(combined_df$dob)
        }

        # Convert age to numeric if present
        if ("age" %in% names(combined_df)) {
            combined_df$age = as.numeric(combined_df$age)
        }

        return(combined_df)
    } else if (format == "csv") {
        url = paste0(BASE_URL, "/v2/killed-in-gaza.csv")
        message(paste("Fetching data from:", url))
        df = readr::read_csv(url, show_col_types = FALSE)

        # Convert date of birth to Date if present
        if ("dob" %in% names(df)) {
            df$dob = as.Date(df$dob)
        }

        # Convert age to numeric if present
        if ("age" %in% names(df)) {
            df$age = as.numeric(df$age)
        }

        return(df)
    } else if (format == "json") {
        if (minified) {
            url = paste0(BASE_URL, "/v2/killed-in-gaza.min.json")
        } else {
            url = paste0(BASE_URL, "/v2/killed-in-gaza.json")
        }
        message(paste("Fetching data from:", url))
        response = httr::GET(url)
        if (httr::status_code(response) == 200) {
            content = httr::content(response, "text", encoding = "UTF-8")
            return(jsonlite::fromJSON(content, flatten = TRUE))
        } else {
            stop(paste(
                "Failed to fetch data. Status code:",
                httr::status_code(response)
            ))
        }
    } else if (format == "page") {
        if (is.null(page)) {
            stop("Page number must be specified when format = 'page'")
        }
        page_url = paste0(BASE_URL, "/v2/killed-in-gaza/page-", page, ".json")
        message(paste("Fetching page", page, "from:", page_url))
        response = httr::GET(page_url)
        if (httr::status_code(response) == 200) {
            content = httr::content(response, "text", encoding = "UTF-8")
            return(jsonlite::fromJSON(content, flatten = TRUE))
        } else {
            stop(paste(
                "Failed to fetch page",
                page,
                ". Status code:",
                httr::status_code(response)
            ))
        }
    } else {
        stop("Invalid format. Please use 'df', 'csv', 'json', or 'page'.")
    }
}
