#' Fetch Files from a GitLab Repository Directory
#'
#' This function lists files in a specific directory of a GitLab repository and optionally downloads them.
#'
#' @param gitlab_url The base URL of the GitLab instance (e.g., "https://gitlab.com").
#' @param project_id The ID or URL-encoded path of the project (e.g., "group/project").
#' @param repo_path The path inside the repository to list/download files from.
#' @param branch The name of the branch.
#' @param download Logical. If TRUE, files will be downloaded. Default is FALSE.
#' @param output_dir The directory where files should be saved if download is TRUE. Default is "gitlab_downloads".
#' @param private_token An optional private token for accessing private repositories.
#'
#' @return A data frame with the list of files (invisibly if downloaded), or NULL if the request fails.
#' @export
#'
#' @importFrom httr GET add_headers status_code content write_disk
#' @importFrom jsonlite fromJSON
#' @importFrom utils URLencode
#'
#' @examples
#' \dontrun{
#' # List files
#' files <- gitlab_fetch_dir(
#'   gitlab_url = "https://gitlab.com",
#'   project_id = "mygroup/myproject",
#'   repo_path = "data",
#'   branch = "main"
#' )
#'
#' # Download files
#' gitlab_fetch_dir(
#'   gitlab_url = "https://gitlab.com",
#'   project_id = "mygroup/myproject",
#'   repo_path = "data",
#'   branch = "main",
#'   download = TRUE,
#'   output_dir = "my_data"
#' )
#' }
gitlab_fetch_dir <- function(
    gitlab_url,
    project_id,
    repo_path,
    branch,
    download = FALSE,
    output_dir = "gitlab_downloads",
    private_token = NULL
) {
    # --- Part 1: Get the list of files from the repository ---
    encoded_project_id <- utils::URLencode(project_id, reserved = TRUE)

    # Ensure no trailing slash in gitlab_url
    gitlab_url <- sub("/+$", "", gitlab_url)

    list_api_url <- paste0(
        gitlab_url,
        "/api/v4/projects/",
        encoded_project_id,
        "/repository/tree"
    )

    query_params <- list(
        recursive = "true",
        per_page = 100,
        path = repo_path,
        ref = branch
    )

    headers <- c()
    if (!is.null(private_token) && nzchar(private_token)) {
        headers['PRIVATE-TOKEN'] <- private_token
    }

    message("Fetching file list from '", repo_path, "'...")
    response <- httr::GET(
        list_api_url,
        httr::add_headers(.headers = headers),
        query = query_params
    )

    if (httr::status_code(response) != 200) {
        message(
            "ERROR: Failed to retrieve file list. Status code: ",
            httr::status_code(response)
        )
        message("URL requested: ", response$url)
        return(NULL)
    }

    content_text <- httr::content(response, "text", encoding = "UTF-8")
    file_list <- jsonlite::fromJSON(content_text, flatten = TRUE)

    if (is.null(file_list) || length(file_list) == 0 || nrow(file_list) == 0) {
        message("No files found.")
        return(NULL)
    }

    message("Success! Found metadata for ", nrow(file_list), " items.")

    # --- Part 2: Decide whether to download based on the 'download' parameter ---
    if (download == FALSE) {
        # Default behavior: just return the data frame
        return(file_list)
    }

    # If download is TRUE, proceed to save files
    if (!dir.exists(output_dir)) {
        dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    }

    message("\nDownloading files into '", output_dir, "' folder...")

    for (i in 1:nrow(file_list)) {
        # Only download blobs (files), skip directories (trees)
        if ("type" %in% names(file_list) && file_list$type[i] != "blob") {
            next
        }

        file_sha <- file_list$id[i]
        # Remove the repo_path prefix from the filename if creating local structure,
        # or keep the relative path structure.
        # The 'path' in file_list usually includes the full path from repo root.
        # If we want to mirror the structure inside output_dir:

        # The API returns 'path' which is the full path.
        # If we are fetching 'repo_path', we might want to strip that prefix for the local dir,
        # or just mirror the full structure. The user's example just used file_name (which might be just the name).
        # Let's check what `file_list$name` contains vs `file_list$path`.
        # 'name' is just the filename, 'path' is full path.
        # If recursive=TRUE, we might get nested files.
        # If we use just 'name', we might have collisions if flattening.
        # Using 'path' is safer but we should probably respect output_dir as root.

        # To keep it simple and robust:
        # We will use file_list$path but prepend output_dir.
        # However, if the user asked for "sub/dir", they might expect "sub/dir" content to be at root of output_dir?
        # Let's stick to the user's logic: "file_name <- file_list$name[i]".
        # Wait, if recursive is true, just using `name` will flatten the structure and overwrite files with same name in diff folders.
        # I will try to preserve structure relative to the requested repo_path if possible,
        # or just use the full path provided by API.

        # User code: output_path <- file.path(output_dir, file_name)
        # I will improve this to use `path` to avoid collisions if recursive.

        rel_path <- file_list$path[i]

        # If we want to strip the parent 'repo_path' from the local path:
        # if (startsWith(rel_path, repo_path)) {
        #   rel_path <- substring(rel_path, nchar(repo_path) + 2) # +2 for slash
        # }
        # But let's keep it simple: mirror the repo structure inside output_dir to be safe.

        final_output_path <- file.path(output_dir, rel_path)

        # Ensure directory exists for this file
        dir.create(
            dirname(final_output_path),
            recursive = TRUE,
            showWarnings = FALSE
        )

        download_api_url <- paste0(
            gitlab_url,
            "/api/v4/projects/",
            encoded_project_id,
            "/repository/blobs/",
            file_sha,
            "/raw"
        )

        dl_response <- httr::GET(
            download_api_url,
            httr::add_headers(.headers = headers),
            httr::write_disk(path = final_output_path, overwrite = TRUE)
        )

        if (httr::status_code(dl_response) == 200) {
            cat(" -> Downloaded:", rel_path, "\n")
        } else {
            cat(
                " -> FAILED:",
                rel_path,
                "(Status:",
                httr::status_code(dl_response),
                ")\n"
            )
        }
    }

    message("\nDownload complete!")
    return(invisible(file_list))
}
