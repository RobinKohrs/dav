#' List Files in a GitLab Repository Recursively
#'
#' This function lists all files in a given path of a GitLab repository recursively.
#' It uses the GitLab API to fetch the repository tree.
#'
#' @param gitlab_url The base URL of the GitLab instance (e.g., "https://gitlab.com").
#' @param project_id The ID or URL-encoded path of the project (e.g., "group/project" or "group%2Fproject").
#' @param path The path inside the repository to list files from. Default is the root ("").
#' @param branch The name of the branch. Default is the repository's default branch.
#' @param private_token An optional private token for accessing private repositories.
#'
#' @return A data frame with the list of files and their attributes, or NULL if the request fails.
#' @export
#'
#' @importFrom httr GET add_headers status_code content
#' @importFrom jsonlite fromJSON
#'
#' @examples
#' \dontrun{
#' # List files in a public repository on gitlab.com
#' files_df <- gitlab_list_repo(
#'   gitlab_url = "https://gitlab.com",
#'   project_id = "gnome/nautilus"
#' )
#'
#' if (!is.null(files_df)) {
#'   print(head(files_df))
#' }
#'
#' # List files in a sub-directory of a project
#' files_in_src <- gitlab_list_repo(
#'   gitlab_url = "https://gitlab.com",
#'   project_id = "gnome/nautilus",
#'   path = "src"
#' )
#'
#' if (!is.null(files_in_src)) {
#'   print(head(files_in_src))
#' }
#' }
gitlab_list_repo <- function(
    gitlab_url,
    project_id,
    path = "",
    branch = "",
    private_token = NULL
) {
    # Correctly encode the project ID (e.g., 'eaws/eaws-regions' becomes 'eaws%2Feaws-regions')
    encoded_project_id <- utils::URLencode(project_id, reserved = TRUE)

    # Construct the API URL
    api_url <- paste0(
        gitlab_url,
        "/api/v4/projects/",
        encoded_project_id,
        "/repository/tree"
    )

    # Set up the query parameters
    query_params <- list(
        recursive = "true",
        per_page = 100, # Max results per page
        path = path,
        ref = branch
    )

    # Set up headers. Only add the private token if it's provided.
    headers <- c()
    if (!is.null(private_token) && private_token != "") {
        headers['PRIVATE-TOKEN'] <- private_token
    }

    # Make the GET request
    response <- GET(
        api_url,
        add_headers(.headers = headers),
        query = query_params
    )

    # Check if the request was successful
    if (status_code(response) == 200) {
        content <- content(response, "text", encoding = "UTF-8")
        files_df <- fromJSON(content, flatten = TRUE)
        return(files_df)
    } else {
        # Print a detailed error message
        message("ERROR: Request failed. See details below.")
        message("URL requested: ", response$url) # This will show you the exact URL it tried
        message("Status Code: ", status_code(response))
        message(
            "Response Body: ",
            content(response, "text", encoding = "UTF-8")
        )
        return(NULL)
    }
}
