#' Ensure Directory Structure for a Path Exists
#'
#' Checks if the directory containing the specified path exists, and creates
#' it recursively if it does not. Provides console feedback using the cli package.
#'
#' @details For a file path like `"/path/to/my/file.txt"`, this function ensures
#'   the directory `"/path/to/my/"` exists. For a directory path like
#'   `"/path/to/my/newdir/"` or `"/path/to/my/newdir"`, it ensures
#'   `"/path/to/my/"` exists. It does *not* create the final component (`file.txt`
#'   or `newdir`) itself, only its parent structure. Console messages indicate
#'   actions taken.
#'
#' @param path A character string specifying the full path (intended for a file
#'   or directory). The function will ensure the *parent* directory of this
#'   path exists.
#' @param showWarnings Logical. Should low-level warnings from `dir.create()`
#'   (e.g., if the directory already exists but with different permissions)
#'   be shown? Defaults to `FALSE`. Note that informational messages from this
#'   function itself are controlled separately (they always show).
#' @param mode The mode to create the directory with, passed to `dir.create()`.
#'   Defaults to `"0777"` (read/write/execute for all). See `?dir.create`.
#'
#' @return The original input `path`, returned invisibly. This is useful for
#'   piping, e.g., `write.csv(my_data, makePath("/path/to/file.csv"))`.
#'
#' @importFrom cli cli_alert_success cli_alert_warning cli_alert_info
#' @export
#' @examples
#' \dontrun{
#' # --- Example 1: Path to a potential file ---
#' temp_file_path = file.path(tempdir(), "makePath_demo", "subdir", "my_data.csv")
#' cat("Demonstrating makePath for:", temp_file_path, "\n")
#' makePath(temp_file_path) # Should create makePath_demo/subdir/
#' makePath(temp_file_path) # Should report directory already exists
#'
#' # --- Example 2: Path to a directory ---
#' temp_dir_path = file.path(tempdir(), "makePath_demo", "another_dir")
#' cat("\nDemonstrating makePath for:", temp_dir_path, "\n")
#' makePath(temp_dir_path) # Should NOT create 'another_dir', but ensure 'makePath_demo' exists
#'
#' # --- Example 3: Path in current directory ---
#' cat("\nDemonstrating makePath for:", "local_file.txt", "\n")
#' makePath("local_file.txt") # Should give warning about not creating "."
#'
#' # --- Example 4: Root directory ---
#' cat("\nDemonstrating makePath for:", "/", "\n")
#' makePath("/") # Should give warning about not creating "/"
#'
#' # --- Clean up example directories ---
#' unlink(file.path(tempdir(), "makePath_demo"), recursive = TRUE)
#' }
sys_make_path = function(path, showWarnings = FALSE, mode = "0777") {

  # --- Input Validation ---
  if (!is.character(path) || length(path) != 1 || is.na(path)) {
    # Use cli for stop messages too, if desired (optional)
    cli::cli_abort("`path` must be a single, non-NA character string.")
  }
  if (path == "") {
    cli::cli_abort("`path` cannot be an empty string.")
  }

  # --- Core Logic ---
  target_dir = dirname(path)

  # Handle edge cases: current dir or root dir
  is_root_or_current = target_dir == "." ||
    target_dir == "/" ||
    (Sys.info()["sysname"] == "Windows" && grepl("^[A-Za-z]:[\\\\/]?$", target_dir))

  if (is_root_or_current) {
    # Use cli_alert_warning for non-action due to edge case
    cli::cli_alert_warning(
      "Parent directory is the current/root directory ({.path {target_dir}}). No directory created by {.fn makePath}."
    )
  } else {
    # Check if the target directory already exists
    if (!dir.exists(target_dir)) {
      # Try to create it recursively
      # dir.create returns TRUE on success, FALSE on failure (and warns on failure)
      success = dir.create(target_dir, recursive = TRUE, showWarnings = showWarnings, mode = mode)

      if (success) {
        # Use cli_alert_success when directory is newly created
        cli::cli_alert_success("Created directory: {.path {target_dir}}")
      } else {
        # If dir.create failed for some reason (permissions?), it usually warns.
        # We can add an extra cli warning or error if needed, but often
        # the base R warning is sufficient if showWarnings = TRUE.
        # If showWarnings = FALSE, we might want an explicit message here.
        if(!showWarnings) {
          cli::cli_alert_danger("Failed to create directory: {.path {target_dir}}. Check permissions.")
        }
        # Even on failure, proceed to return path invisibly
      }
    } else {
      # Use cli_alert_info if directory already existed (optional but helpful)
      cli::cli_alert_info("Parent directory already exists: {.path {target_dir}}")
    }
  }

  # --- Return Value ---
  invisible(path)
}
