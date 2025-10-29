#' Authenticate with Datawrapper for a Specific Employer
#'
#' These functions manage and set the `DW_KEY` environment variable for the
#' current R session, allowing you to easily switch between different
#' Datawrapper accounts (e.g., for different employers).
#'
#' The first time you use one of these functions for a specific employer, you must
#' provide the `api_key`. This key will be stored securely in your local
#' `.Renviron` file as `DW_KEY_DST` or `DW_KEY_NDR`. On subsequent uses, you
#' can call the function without an `api_key` to load the stored key for your
#' current R session.
#'
#' @md
#' @param api_key Optional. A character string containing the Datawrapper API key.
#'   If provided, the key will be saved to your `.Renviron` file for future use.
#'
#' @return Invisibly returns the API key that was set. It also prints a
#'   confirmation message to the console.
#' @name dw_auth
#' @author Benedict Witzenberger, Robin Kohrs
NULL

#' @rdname dw_auth
#' @export
#' @examples
#' \dontrun{
#' # First time usage (stores the key):
#' dw_dst(api_key = "your_api_key_for_dst")
#'
#' # Subsequent usage in a new R session:
#' dw_dst()
#' }
dw_dst <- function(api_key = NULL) {
    dw_auth_key("DW_KEY_DST", api_key)
}

#' @rdname dw_auth
#' @export
#' @examples
#' \dontrun{
#' # First time usage (stores the key):
#' dw_ndr(api_key = "your_api_key_for_ndr")
#'
#' # Subsequent usage in a new R session:
#' dw_ndr()
#' }
dw_ndr <- function(api_key = NULL) {
    dw_auth_key("DW_KEY_NDR", api_key)
}

#' Helper Function to Set and Load Datawrapper API Keys
#'
#' This internal function handles the logic for storing, retrieving, and setting
#' employer-specific API keys.
#'
#' @param key_name The name of the environment variable to use for storage
#'   (e.g., "DW_KEY_DST").
#' @param api_key The API key string, or `NULL`.
#' @keywords internal
dw_auth_key <- function(key_name, api_key = NULL) {
    # Path to the .Renviron file in the user's home directory
    renviron_path <- file.path(Sys.getenv("HOME"), ".Renviron")

    # Create .Renviron if it doesn't exist
    if (!file.exists(renviron_path)) {
        file.create(renviron_path)
    }

    # If a new API key is provided, save or update it in .Renviron
    if (!is.null(api_key)) {
        lines <- if (file.exists(renviron_path)) {
            readLines(renviron_path)
        } else {
            character()
        }

        # Remove any existing line for this key
        lines <- lines[!grepl(paste0("^", key_name), lines)]

        # Add the new key
        new_key_line <- paste0(key_name, "='", api_key, "'")
        lines <- c(lines, new_key_line)

        writeLines(lines, renviron_path)

        # Reload the environment to make the new key available
        readRenviron(renviron_path)
        message(
            "API key for ",
            key_name,
            " has been saved to your .Renviron file."
        )
    }

    # Retrieve the key from the environment
    stored_key <- Sys.getenv(key_name)

    # Check if the key exists
    if (identical(stored_key, "")) {
        stop(
            "No API key found for ",
            key_name,
            ".\n",
            "Please provide the key once to save it, e.g., dw_dst(api_key = 'YOUR_KEY').",
            call. = FALSE
        )
    }

    # Set the main DW_KEY for the current session for compatibility with DatawRappr
    Sys.setenv(DW_KEY = stored_key)

    message("Datawrapper ", key_name, " authenticated for the current session.")
    invisible(stored_key)
}
