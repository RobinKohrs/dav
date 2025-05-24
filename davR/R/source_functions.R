#' Source all R functions from the functions directory
#'
#' This function sources all .R files from the functions directory in the current project.
#' It's designed to be used at the start of analysis scripts to load all custom functions
#' without the overhead of creating a full R package.
#'
#' @param verbose Logical. If TRUE, prints which files are being sourced. Default is FALSE.
#' @param recursive Logical. If TRUE, also sources functions from subdirectories. Default is FALSE.
#' @param pattern Character. Regular expression pattern for files to source. Default is "\\.R$".
#'
#' @return Invisibly returns a character vector of sourced file paths
#' @export
#'
#' @examples
#' # Source all R files in the functions directory
#' source_functions()
#'
#' # Source with verbose output
#' source_functions(verbose = TRUE)
#'
#' # Source including subdirectories
#' source_functions(recursive = TRUE)
sys_source_functions = function(
    verbose = FALSE,
    recursive = FALSE,
    pattern = "\\.R$"
) {
    # Get the path to the functions directory relative to the project root
    functions_dir = here::here("R", "functions")

    if (!dir.exists(functions_dir)) {
        stop("Functions directory not found at: ", functions_dir)
    }

    # Get all R files
    r_files = list.files(
        path = functions_dir,
        pattern = pattern,
        full.names = TRUE,
        recursive = recursive
    )

    if (length(r_files) == 0) {
        if (verbose) {
            message("No R files found in: ", functions_dir)
        }
        return(invisible(character(0)))
    }

    # Source each file
    for (file in r_files) {
        if (verbose) {
            message("Sourcing: ", basename(file))
        }
        source(file, local = FALSE)
    }

    if (verbose) {
        message("\nSourced ", length(r_files), " R files from: ", functions_dir)
    }

    invisible(r_files)
}
