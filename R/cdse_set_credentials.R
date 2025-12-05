#' Set Copernicus Data Space Ecosystem Credentials
#'
#' Reads AWS credentials from the standard AWS credentials file (`~/.aws/credentials`)
#' for a specific profile (defaulting to "copernicus").
#'
#' @param profile Character. The name of the profile to read from the credentials file.
#'   Defaults to "copernicus".
#' @param file Character. Path to the AWS credentials file.
#'   Defaults to "~/.aws/credentials".
#'
#' @return A named list containing `access_key` and `secret_key`, or NULL if not found.
#' @export
cdse_set_credentials <- function(
    profile = "copernicus",
    file = "~/.aws/credentials"
) {
    path <- path.expand(file)

    if (!file.exists(path)) {
        warning(paste("Credentials file not found at:", path))
        return(NULL)
    }

    # Read the file line by line
    lines <- readLines(path, warn = FALSE)

    # Find the profile section
    # Look for [profile_name]
    profile_header <- paste0("[", profile, "]")
    start_idx <- which(trimws(lines) == profile_header)

    if (length(start_idx) == 0) {
        warning(paste("Profile", profile, "not found in", path))
        return(NULL)
    }

    # Read lines after the profile header until the next section or end of file
    # Initialize keys
    access_key <- NULL
    secret_key <- NULL

    # Iterate through lines starting after the profile header
    # We stop if we hit another header [...] or end of lines
    for (i in (start_idx + 1):length(lines)) {
        line <- trimws(lines[i])

        # Stop if empty line or next section
        if (line == "" || grepl("^\\[.*\\]$", line)) {
            if (i > start_idx + 1 && !is.null(access_key)) {
                break
            } # optimization
            if (grepl("^\\[.*\\]$", line)) {
                break
            }
            next
        }

        # Parse key=value
        if (grepl("^aws_access_key_id", line, ignore.case = TRUE)) {
            access_key <- trimws(sub("^[^=]+=", "", line))
        } else if (grepl("^aws_secret_access_key", line, ignore.case = TRUE)) {
            secret_key <- trimws(sub("^[^=]+=", "", line))
        }
    }

    if (is.null(access_key) || is.null(secret_key)) {
        warning(
            "Could not find aws_access_key_id or aws_secret_access_key in profile."
        )
        return(NULL)
    }

    # Automatically set them in the environment for convenience
    Sys.setenv("AWS_ACCESS_KEY_ID" = access_key)
    Sys.setenv("AWS_SECRET_ACCESS_KEY" = secret_key)

    message("Credentials for profile '", profile, "' set successfully.")

    return(invisible(list(
        access_key = access_key,
        secret_key = secret_key
    )))
}
