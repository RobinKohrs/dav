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
#' print(top_names$lists$girl)
#' print(top_names$lists$boy)
#' print(top_names$lists$woman)
#' print(top_names$lists$man)
#'
#' # Get child counts
#' print(top_names$totalPeople$boy)   # Total boys: 10656
#' print(top_names$totalPeople$girl)   # Total girls: 7801
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
