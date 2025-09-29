#' Ensure Directory Structure Exists (Custom Heuristic for File/Directory)
#'
#' Creates the necessary directory structure. It uses a custom heuristic to
#' determine if the input `path` is intended as a file or a directory.
#'
#' @details
#' The function's heuristic is as follows:
#' 1. If `path` already exists:
#'    - If it's a directory (per `file.info()`), no creation action is taken for it.
#'    - If it's a file (per `file.info()`), its parent directory is targeted for creation.
#' 2. If `path` does not exist:
#'    - If the original `path` string ends with one or more path separators ('/' or '\'),
#'      the full `path` is treated as a directory to be created.
#'    - Else, if the last component (basename) of the `path` does *not* contain a
#'      dot ('.'), the full `path` is treated as a directory to be created.
#'    - Otherwise (does not end with a separator AND basename contains a dot),
#'      it's treated as a file path, and its parent directory is targeted for creation.
#' Provides console feedback using the cli package.
#'
#' @param path A character string specifying the full path.
#' @param showWarnings Logical. Passed to `dir.create()`. Defaults to `FALSE`.
#' @param mode Character. The mode for `dir.create()`. Defaults to `"0777"`.
#'
#' @return The original input `path`, returned invisibly.
#'
#' @importFrom cli cli_abort cli_alert_success cli_alert_warning cli_alert_info cli_alert_danger
# @importFrom tools file_path_as_absolute # Replaced with normalizePath
#' @export
sys_make_path = function(path, showWarnings = FALSE, mode = "0777") {

  if (!is.character(path) || length(path) != 1 || is.na(path) || path == "") {
    cli::cli_abort("`path` must be a single, non-empty, non-NA character string.")
  }

  original_path = path
  # Use normalizePath with mustWork = FALSE to get an absolute path string
  # even if the path doesn't exist yet. This also resolves "..", "." etc.
  normalized_path = normalizePath(original_path, winslash = "/", mustWork = FALSE)

  target_dir_to_create = NULL
  action_description = ""
  path_for_display = gsub("[/\\]+$", "", normalized_path)
  if (path_for_display == "") path_for_display = normalized_path


  f_info = file.info(normalized_path)

  if (!is.na(f_info$isdir)) {
    if (f_info$isdir) {
      cli::cli_alert_info("Path {.path {path_for_display}} already exists as a directory.")
      return(invisible(original_path))
    } else {
      target_dir_to_create = dirname(normalized_path)
      action_description = "parent directory for existing file"
      path_for_display = target_dir_to_create # Update display path to the target
    }
  } else {
    ends_with_one_or_more_separators = grepl("[/\\]+$", original_path)
    last_component = basename(normalized_path) # basename works on non-existent paths
    basename_has_no_dot = !grepl("\\.", last_component, fixed = FALSE)

    if (ends_with_one_or_more_separators) {
      target_dir_to_create = normalized_path
      action_description = "directory (path ended with separator(s), non-existent)"
      # path_for_display is already set to the normalized path without trailing slashes
    } else if (basename_has_no_dot) {
      target_dir_to_create = normalized_path
      action_description = "directory (basename has no dot, non-existent)"
      # path_for_display is already set
    } else {
      target_dir_to_create = dirname(normalized_path) # dirname works on non-existent paths
      action_description = "parent directory for file (basename has dot, no trailing slash, non-existent)"
      path_for_display = target_dir_to_create # Update display path
    }
  }

  # Edge cases for the directory we actually intend to create
  # For is_root_or_current, compare against normalized versions of "." and "/"
  # Use target_dir_to_create for this check as it's what we'd attempt to operate on
  is_root_or_current = target_dir_to_create == normalizePath(".", winslash = "/") ||
    target_dir_to_create == normalizePath("/", winslash = "/") ||
    (Sys.info()["sysname"] == "Windows" && grepl("^[A-Za-z]:[\\\\/]?$", target_dir_to_create))


  if (is_root_or_current) {
    # dir.exists on target_dir_to_create (which is already normalized)
    if(dir.exists(target_dir_to_create)){
      cli::cli_alert_info(
        "Target ({action_description}) is the current/root directory ({.path {target_dir_to_create}}) and already exists."
      )
    } else {
      cli::cli_alert_warning(
        "Target ({action_description}) is current/root ({.path {target_dir_to_create}}) but doesn't seem to exist. This is unexpected."
      )
    }
  } else {
    if (!dir.exists(target_dir_to_create)) {
      cli::cli_alert_info("Target ({action_description}) {.path {path_for_display}} does not exist. Attempting to create.")
      success = dir.create(target_dir_to_create, recursive = TRUE, showWarnings = showWarnings, mode = mode)

      if (success) {
        cli::cli_alert_success("Successfully created ({action_description}): {.path {path_for_display}}")
      } else {
        if (dir.exists(target_dir_to_create)) {
          cli::cli_alert_info("({action_description}) {.path {path_for_display}} now exists (possibly created by another process).")
        } else if (!showWarnings) {
          cli::cli_alert_danger("Failed to create ({action_description}): {.path {path_for_display}}. Check permissions or path validity.")
        }
      }
    } else {
      cli::cli_alert_info("Target ({action_description}) already exists: {.path {path_for_display}}")
    }
  }
  invisible(original_path)
}
