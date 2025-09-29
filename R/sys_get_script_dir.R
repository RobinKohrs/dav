#' Get Directory of the Currently Executing R Script
#'
#' This function attempts to robustly determine and return the absolute path
#' to the directory containing the currently executing R script. It tries
#' various methods to accommodate different execution contexts such as
#' RStudio, `knitr` (R Markdown/Quarto), `source()`, and `Rscript`.
#' It prints an informative message indicating the method used.
#'
#' @details
#' The function employs the following strategies in order to find the script's path:
#' \enumerate{
#'   \item **RStudio API:** If run within RStudio and a document is active, it uses
#'     `rstudioapi::getActiveDocumentContext()$path`.
#'   \item **`knitr` Environment:** If the script is processed by `knitr` (e.g., within
#'     an R Markdown or Quarto document), it uses `knitr::current_input(dir = FALSE)` to get the
#'     source file, then its directory.
#'   \item **`source()` Context:** If the script is being `source()`d, it checks
#'     parent frames for an `ofile` component.
#'   \item **`Rscript` Execution:** If the script is run via `Rscript` from the command
#'     line, it parses `commandArgs()` for the `--file=` argument.
#' }
#'
#' If all methods fail to determine the script's path, the function will
#' stop with an error message. It does *not* fall back to the working
#' directory (`getwd()`) to avoid ambiguity.
#'
#' The returned path is normalized to an absolute path.
#'
#' @param script_path_override (Optional) A character string. If provided, this
#'   path will be used directly instead of attempting auto-detection. If it's
#'   a file path, its directory will be returned. If it's a directory path,
#'   it will be returned as is. This is useful for testing or when the script's
#'   location is known through other means.
#' @param verbose Logical. If `TRUE` (default), prints a message indicating how
#'   the script directory was determined or if it failed.
#'
#' @return A character string representing the absolute path to the directory
#'   of the currently executing script.
#' @export
#' @importFrom tools file_path_as_absolute
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_danger cli_text
#'
#' @examples
#' \dontrun{
#' # --- Assuming this code is saved in a file named "my_script.R" ---
#'
#' # 1. When run directly in RStudio (after saving the script):
#' #    script_dir <- sys_get_script_dir()
#' #    # Expected output:
#' #    # ✓ Script directory determined via User Override (File Path): /path/to/temp_dir_for_file
#' #    # or for auto-detection:
#' #    # ℹ Script directory determined via RStudio API: /path/to/your/script
#' #    print(script_dir)
#'
#' # 5. Using the override (e.g., for testing or known path):
#' temp_file <- tempfile(fileext = ".R")
#' writeLines("print('hello')", temp_file)
#' known_dir <- sys_get_script_dir(script_path_override = temp_file) # verbose=TRUE by default
#' unlink(temp_file)
#'
#' temp_dir <- tempfile("my_dir_")
#' dir.create(temp_dir)
#' known_dir_from_dir <- sys_get_script_dir(script_path_override = temp_dir)
#' unlink(temp_dir, recursive = TRUE)
#'
#' # Example of failure:
#' tryCatch({
#'   # In a context where it can't be found (e.g. bare R console with no script)
#'   sys_get_script_dir(verbose = TRUE)
#' }, error = function(e) { message(e$message) })
#' }
sys_get_script_dir = function(script_path_override = NULL, verbose = TRUE) {
  # Helper for conditional messaging
  .inform = function(type, ...) { # Use ... to pass arguments to cli functions
    if (verbose) {
      if (requireNamespace("cli", quietly = TRUE)) {
        args_list = list(...)
        if (type == "info") {
          do.call(cli::cli_alert_info, args_list)
        } else if (type == "success") {
          do.call(cli::cli_alert_success, args_list)
        } else if (type == "danger") {
          do.call(cli::cli_alert_danger, args_list)
        } else {
          # Fallback to cli_text if type is unknown or for general text
          do.call(cli::cli_text, args_list)
        }
      } else {
        # Fallback to base R message - combine ... into a single string
        message_text = paste(unlist(list(...)), collapse = "")
        message(paste0(toupper(type), ": ", message_text))
      }
    }
  }

  determined_path = NULL
  method_used_msg = NULL # Store the message string for the method used

  # 1. Use script_path_override if provided
  if (!is.null(script_path_override)) {
    if (!is.character(script_path_override) || length(script_path_override) != 1) {
      stop("'script_path_override' must be a single character string or NULL.")
    }
    original_override_for_msg = script_path_override
    normalized_override = tryCatch(
      tools::file_path_as_absolute(script_path_override),
      error = function(e) {
        stop("Could not normalize 'script_path_override': ", script_path_override, ". Error: ", e$message)
      }
    )
    if (dir.exists(normalized_override)) {
      determined_path = normalized_override
      method_used_msg = "User Override (Directory)"
    } else if (file.exists(normalized_override)) {
      determined_path = dirname(normalized_override)
      method_used_msg = "User Override (File Path)"
    } else {
      stop("Provided 'script_path_override' (", normalized_override, ") does not exist as a file or directory.")
    }
    .inform("success", "Script directory determined via {.strong {method_used_msg}}: {.path {determined_path}} (from override: {.file {original_override_for_msg}})")
    return(determined_path)
  }

  # Auto-detection methods

  # 2. Try RStudio API
  if (is.null(determined_path)) {
    if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
      tryCatch({
        doc_context = rstudioapi::getActiveDocumentContext()
        if (!is.null(doc_context) && !is.null(doc_context$path) && nzchar(doc_context$path)) {
          rstudio_file_path_abs = tools::file_path_as_absolute(doc_context$path)
          if(file.exists(rstudio_file_path_abs)){
            determined_path = dirname(rstudio_file_path_abs)
            method_used_msg = "RStudio API"
          }
        }
      }, error = function(e) {
        # Silently ignore: R will continue to the next method
      })
    }
  }

  # 3. Try knitr environment
  if (is.null(determined_path)) {
    if (requireNamespace("knitr", quietly = TRUE) && exists("current_input", where = asNamespace("knitr"))) {
      tryCatch({
        knitr_input_file = knitr::current_input(dir = FALSE)
        if (!is.null(knitr_input_file) && nzchar(knitr_input_file)) {
          abs_knitr_input_file = tools::file_path_as_absolute(knitr_input_file)
          if(file.exists(abs_knitr_input_file)) {
            determined_path = dirname(abs_knitr_input_file)
            method_used_msg = "knitr::current_input() [file]"
          } else {
            knitr_input_dir = knitr::current_input(dir = TRUE)
            if (!is.null(knitr_input_dir) && nzchar(knitr_input_dir)) {
              abs_knitr_input_dir = tools::file_path_as_absolute(knitr_input_dir)
              if(dir.exists(abs_knitr_input_dir)){
                determined_path = abs_knitr_input_dir
                method_used_msg = "knitr::current_input(dir = TRUE) [directory]"
              }
            }
          }
        }
      }, error = function(e) {
        # Silently ignore: R will continue to the next method
      })
    }
  }

  # 4. Try source() context
  if (is.null(determined_path)) {
    tryCatch({
      for (i in sys.nframe():1) {
        frame_env = sys.frame(i)
        if (exists("ofile", envir = frame_env, inherits = FALSE)) {
          sourced_file_candidate = frame_env$ofile
          if (!is.null(sourced_file_candidate) && nzchar(sourced_file_candidate)) {
            abs_sourced_file_candidate = tools::file_path_as_absolute(sourced_file_candidate)
            if (file.exists(abs_sourced_file_candidate)) {
              determined_path = dirname(abs_sourced_file_candidate)
              method_used_msg = paste0("sys.frame(", i, ")$ofile")
              break
            }
          }
        }
      }
    }, error = function(e) {
      # Silently ignore: R will continue to the next method
    })
  }

  # 5. Try Rscript execution (commandArgs)
  if (is.null(determined_path)) {
    cmd_args = commandArgs(trailingOnly = FALSE)
    file_arg_match = grepl("^--file=", cmd_args)
    if (any(file_arg_match)) {
      script_file_path = sub("^--file=", "", cmd_args[which(file_arg_match)[1]])
      abs_script_file_path = tools::file_path_as_absolute(script_file_path)
      if (file.exists(abs_script_file_path)) {
        determined_path = dirname(abs_script_file_path)
        method_used_msg = "Rscript (--file= argument)"
      }
    }
  }

  # Final reporting
  if (!is.null(determined_path) && !is.null(method_used_msg)) {
    .inform("info", "Script directory determined via {.strong {method_used_msg}}: {.path {determined_path}}")
  } else if (is.null(determined_path)) {
    final_message = "Could not determine the script's directory. Tried RStudio, knitr, source, and Rscript contexts. Ensure the script is run in a recognized environment or provide 'script_path_override'."
    .inform("danger", final_message)
    stop(final_message, call. = FALSE)
  }

  return(determined_path)
}
