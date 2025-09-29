# Gaza Advanced Data Functions
# ==============================================================================

#' Fetches the counts of the top 10 translated first names by age group
#'
#' @details
#' This dataset is used to derive estimates of children killed for the home page name cards as documented on the Summary dataset page.
#'
#' @return A list containing the name frequency data, categorized by age group.
#'
#' @examples
#' # Get top translated names by age group
#' top_names = gaza_top_translated_names()
#' print(top_names$girl)
#' print(top_names$boy)
#' print(top_names$woman)
#' print(top_names$man)
#'
#' @export
gaza_top_translated_names = function() {
    url = paste0(BASE_URL, "/v2/killed-in-gaza/name-freq-en.json")
    message(paste("Fetching top translated names data from:", url))
    response = httr::GET(url)
    if (httr::status_code(response) == 200) {
        content = httr::content(response, "text", encoding = "UTF-8")
        return(jsonlite::fromJSON(content))
    } else {
        stop(paste(
            "Failed to fetch top translated names data. Status code:",
            httr::status_code(response)
        ))
    }
}

#' Fetches estimated counts of children killed, grouped by name
#'
#' @details
#' This dataset is used to derive the estimates for the "killed children by name" visualizations on the Palestine Datasets website. The logic for this calculation can be seen in JavaScript on GitHub. It's available as a JSON API that updates as both the summary dataset and the Killed in Gaza names list receive updates.
#'
#' @return A data frame containing the child name count estimates.
#'
#' @examples
#' # Get child name counts
#' child_counts = gaza_child_name_counts()
#' head(child_counts)
#'
#' @export
gaza_child_name_counts = function() {
    url = paste0(BASE_URL, "/v2/killed-in-gaza/child-name-counts-en.json")
    message(paste("Fetching child name counts data from:", url))
    response = httr::GET(url)
    if (httr::status_code(response) == 200) {
        content = httr::content(response, "text", encoding = "UTF-8")
        return(jsonlite::fromJSON(content, flatten = TRUE))
    } else {
        stop(paste(
            "Failed to fetch child name counts data. Status code:",
            httr::status_code(response)
        ))
    }
}
