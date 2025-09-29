#' @title Download HTTPS Files from Geosphere

#' @importFrom httr GET add_headers write_disk progress status_code content timeout
#' @importFrom glue glue
#' @importFrom cli cli_h1 cli_alert_info cli_alert_success cli_alert_danger cli_alert_warning cli_abort
#' @importFrom tools file_path_sans_ext
#' @importFrom utils packageName packageVersion data
#'
#' @description
#' Downloads a single file from the Geosphere Austria data hub by constructing
#' its URL from specified components: resource ID, optional subpath parts within
#' the resource, and the filename. This function is intended for direct file
#' downloads where the full path structure to the file is known or can be constructed.
#'
#' @param dest_dir The directory where the downloaded file will be saved.
#'                 If it doesn't exist, it will be created.
#' @param filename The name of the file to download (e.g., "SPARTACUS2-DAILY_TX_2020.nc").
#' @param resource_id The specific resource ID (e.g., "spartacus-v2-1d-1km").
#' @param resource_subpath_parts A character vector of path segments that appear
#'                               *after* the `resource_id` and *before* the `filename`
#'                               in the URL. If `NULL` (default),
#'                               the filename is assumed to be directly under the `resource_id` path.
#' @param base_data_url The base URL for accessing Geosphere Austria resource data.
#' @param user_agent Custom User-Agent string for the HTTP request.
#' @param overwrite Logical. If `TRUE`, an existing file in `dest_dir` with the same name
#'                  will be overwritten. If `FALSE` (default), an existing file will be skipped.
#' @param verbose Logical. If `TRUE` (default), prints informational messages.
#' @param timeout_seconds Request timeout in seconds. Passed to `httr::GET`.
#'
#' @return The full path to the successfully downloaded or already existing file if successful,
#'         otherwise `NA_character_` if the download failed.
#' @export
#'
#' @examples
#' \dontrun{
#' # Create a temporary directory for downloads
#' temp_dl_dir = tempfile("geosphere_pkg_dl_")
#' dir.create(temp_dl_dir)
#'
#' # Example 1: Download SPARTACUS TX data for 2020
#' spartacus_file = geosphere_download_from_filelisting(
#'   dest_dir = temp_dl_dir,
#'   filename = "SPARTACUS2-DAILY_TX_2020.nc",
#'   resource_id = "spartacus-v2-1d-1km",
#'   verbose = TRUE
#' )
#' if (!is.na(spartacus_file)) print(paste("Downloaded:", spartacus_file))
#'
#' # Example 2: Download APOLIS data with subpath
#' apolis_file = geosphere_download_from_filelisting(
#'   dest_dir = temp_dl_dir,
#'   filename = "APOLIS_2006_01.nc",
#'   resource_id = "apolis-short-daily-dir-hori",
#'   resource_subpath_parts = c("2006", "01"),
#'   verbose = TRUE
#' )
#' if (!is.na(apolis_file)) print(paste("Downloaded:", apolis_file))
#'
#' # Example 3: Download VDL data with multiple subpath parts
#' vdl_file = geosphere_download_from_filelisting(
#'   dest_dir = temp_dl_dir,
#'   filename = "t2m_2022_01_15.nc",
#'   resource_id = "vdl-standard-v1-1h-1km-era5land-downscaled",
#'   resource_subpath_parts = c("2022", "01", "15", "t2m"),
#'   verbose = TRUE
#' )
#' if (!is.na(vdl_file)) print(paste("Downloaded:", vdl_file))
#'
#' # Clean up
#' unlink(temp_dl_dir, recursive = TRUE)
#' }
geosphere_download_from_filelisting = function(
    dest_dir,
    filename,
    resource_id,
    resource_subpath_parts = NULL,
    base_data_url = "https://public.hub.geosphere.at/datahub/resources/",
    user_agent = "R Package (davR File Download)",
    overwrite = FALSE,
    verbose = TRUE,
    timeout_seconds = 300
) {

  # --- Input Validation ---
  if (missing(dest_dir) || !is.character(dest_dir) || length(dest_dir) != 1 || !nzchar(dest_dir)) {
    stop("`dest_dir` must be a single, non-empty character string.", call. = FALSE)
  }
  if (missing(filename) || !is.character(filename) || length(filename) != 1 || !nzchar(filename)) {
    stop("`filename` must be a single, non-empty character string.", call. = FALSE)
  }
  if (missing(resource_id) || !is.character(resource_id) || length(resource_id) != 1 || !nzchar(resource_id)) {
    stop("`resource_id` must be a single, non-empty character string.", call. = FALSE)
  }
  if (!is.null(resource_subpath_parts) && (!is.character(resource_subpath_parts) || any(!nzchar(trimws(resource_subpath_parts))))) {
    stop("`resource_subpath_parts` must be NULL or a character vector of non-empty strings.", call. = FALSE)
  }
  if (!is.character(base_data_url) || length(base_data_url) != 1 || !nzchar(base_data_url)) {
    stop("`base_data_url` must be a single, non-empty character string.", call. = FALSE)
  }

  # --- Setup ---
  if (!dir.exists(dest_dir)) {
    if (verbose) {
      cli::cli_alert_info("Creating destination directory: {.path {dest_dir}}")
    }
    tryCatch(
      dir.create(dest_dir, recursive = TRUE),
      error = function(e) {
        stop(glue::glue("Failed to create destination directory '{dest_dir}'. Error: {e$message}"), call. = FALSE)
      }
    )
  }
  dest_dir = normalizePath(dest_dir, mustWork = TRUE)
  destination_path = file.path(dest_dir, filename)

  request_headers = httr::add_headers(`User-Agent` = user_agent)

  # --- Construct the URL ---
  cleaned_base_data_url = if (endsWith(base_data_url, "/")) base_data_url else paste0(base_data_url, "/")
  cleaned_resource_id = gsub("^/|/$", "", resource_id)
  path_components = c(cleaned_resource_id)

  if (!is.null(resource_subpath_parts)) {
    cleaned_subpath_parts = vapply(resource_subpath_parts, function(s) gsub("^/|/$", "", s), character(1))
    path_components = c(path_components, cleaned_subpath_parts)
  }
  path_components = c(path_components, filename)
  relative_url_path = paste(path_components, collapse = "/")
  full_url = paste0(cleaned_base_data_url, relative_url_path)

  if (verbose) {
    cli::cli_h1(glue::glue("Downloading File: {filename}"))
    cli::cli_alert_info("Resource ID: {resource_id}")
    if (!is.null(resource_subpath_parts)) {
      cli::cli_alert_info("Subpath Parts: {paste(resource_subpath_parts, collapse = '/')}")
    }
    cli::cli_alert_info("Full Target URL: {.url {full_url}}")
    cli::cli_alert_info("Destination Path: {.path {destination_path}}")
  }

  if (file.exists(destination_path) && !overwrite) {
    if (verbose) {
      cli::cli_alert_success("File already exists and overwrite is FALSE. Skipping: {.path {destination_path}}")
    }
    return(destination_path)
  }

  # --- Perform Download ---
  response = tryCatch({
    if (verbose) cli::cli_alert_info("Attempting download...")
    httr::GET(
      url = full_url,
      request_headers,
      httr::write_disk(destination_path, overwrite = TRUE),
      httr::progress("down"),
      httr::timeout(timeout_seconds)
    )
  }, error = function(e) {
    if (verbose) {
      cli::cli_alert_danger("Network error during download of '{filename}':")
      cli::cli_alert_danger(conditionMessage(e))
    }
    if (file.exists(destination_path)) try(file.remove(destination_path), silent = TRUE)
    return(NULL)
  })

  if (is.null(response)) {
    return(NA_character_)
  }

  if (httr::status_code(response) == 200) {
    if (verbose) {
      cli::cli_alert_success("Download successful for '{filename}' to {.path {destination_path}}")
    }
    return(destination_path)
  } else {
    if (verbose) {
      cli::cli_alert_danger("Download failed for '{filename}'. HTTP Status: {httr::status_code(response)}")
      error_content = tryCatch(httr::content(response, "text", encoding = "UTF-8"), error = function(e) "Could not retrieve error content.")
      cli::cli_alert_info("Response content (first 200 chars): {.val {substr(error_content, 1, 200)}}")
    }
    if (file.exists(destination_path)) try(file.remove(destination_path), silent = TRUE)
    return(NA_character_)
  }
}


#' Download File Using a Predefined Geosphere Schema
#'
#' @description
#' Constructs the filename and subpath based on a predefined internal schema for a given
#' Geosphere Austria `resource_id` and a set of parameters, then downloads the file.
#' This is an internal helper function for downloading known datasets.
#'
#' @param dest_dir Directory to save the file.
#' @param resource_id The key in the internal schemas list corresponding to the dataset
#'                    (e.g., "spartacus-v2-1d-1km"). This is also the `resource_id`
#'                    used in the URL.
#' @param params A named list of parameter values to fill into the templates
#'               (e.g., `list(year = 2020, variable_type = "TX")`).
#' @param base_data_url Base URL for Geosphere data.
#' @param user_agent Custom User-Agent. If `NULL`, a default package user agent is used.
#' @param overwrite Logical, whether to overwrite existing files.
#' @param verbose Logical, for verbose output.
#' @param timeout_seconds Request timeout.
#'
#' @return Path to the downloaded file or `NA_character_` on failure.
#' @keywords internal
geosphere_download_from_schema = function(
    dest_dir,
    resource_id,
    params,
    base_data_url = "https://public.hub.geosphere.at/datahub/resources/",
    user_agent = NULL,
    overwrite = FALSE,
    verbose = TRUE,
    timeout_seconds = 300
) {

  # Access GEOSPHERE_DATA_SCHEMAS from the package's internal data
  # This object is created by the script in data-raw/ and saved to R/sysdata.rda
  current_package_name = utils::packageName()
  if (is.null(current_package_name)) {
    # This might happen if run interactively not as part of a loaded package
    # For development, you might load it manually or ensure it's in .GlobalEnv
    if (exists("GEOSPHERE_DATA_SCHEMAS", envir = .GlobalEnv)) {
      current_schemas = get("GEOSPHERE_DATA_SCHEMAS", envir = .GlobalEnv)
    } else {
      cli::cli_abort(
        "Internal `GEOSPHERE_DATA_SCHEMAS` not found. If developing, ensure it's loaded or run `source('data-raw/your_schema_script.R')`."
      )
      return(NA_character_)
    }
  } else {
    # When package is loaded, GEOSPHERE_DATA_SCHEMAS should be in the package namespace
    # Note: Direct access `GEOSPHERE_DATA_SCHEMAS` usually works if R/sysdata.rda is correct
    # and the package is loaded. The `get()` below is more explicit.
    if (exists("GEOSPHERE_DATA_SCHEMAS", envir = asNamespace(current_package_name), inherits = FALSE)) {
      current_schemas = get("GEOSPHERE_DATA_SCHEMAS", envir = asNamespace(current_package_name))
    } else {
      cli::cli_abort(
        "Internal `GEOSPHERE_DATA_SCHEMAS` not found in package '{current_package_name}'. This is a package setup issue. Ensure R/sysdata.rda is correctly built and contains this object."
      )
      return(NA_character_)
    }
  }

  if (!resource_id %in% names(current_schemas)) {
    cli::cli_abort("Schema for `resource_id` '{resource_id}' not found in internal schemas.")
    return(NA_character_)
  }

  schema = current_schemas[[resource_id]]

  defined_params = names(schema$parameters)
  provided_params = names(params)
  missing_params = setdiff(defined_params, provided_params)
  extra_params = setdiff(provided_params, defined_params)

  if (length(missing_params) > 0) {
    cli::cli_abort("Missing required parameters for schema '{resource_id}': {missing_params}")
    return(NA_character_)
  }
  if (length(extra_params) > 0) {
    if (verbose) {
      cli::cli_alert_warning("Ignoring extra parameters provided for schema '{resource_id}': {extra_params}")
    }
    params = params[names(params) %in% defined_params]
  }

  for (p_name in defined_params) {
    param_schema = schema$parameters[[p_name]]
    if (!is.null(param_schema$allowed_values)) {
      if (!(params[[p_name]] %in% param_schema$allowed_values)) {
        cli::cli_abort(c(
          "Parameter '{p_name}' value '{.val {params[[p_name]]}}' is not among allowed values for schema '{resource_id}'.",
          "i" = "Allowed values are: {.or {.val {param_schema$allowed_values}}}"
        ))
        return(NA_character_)
      }
    }
    if (!is.null(param_schema$type)) {
      expected_type = param_schema$type
      actual_value = params[[p_name]]
      type_match = FALSE
      if (expected_type == "integer" && (is.integer(actual_value) || (is.numeric(actual_value) && actual_value == round(actual_value)))) {
        type_match = TRUE
        if(!is.integer(actual_value)) params[[p_name]] = as.integer(actual_value) # Coerce if numeric whole number
      } else if (expected_type == "numeric" && is.numeric(actual_value)) {
        type_match = TRUE
      } else if (expected_type == "character" && is.character(actual_value)) {
        type_match = TRUE
      } else if (expected_type == "logical" && is.logical(actual_value)) {
        type_match = TRUE
      }

      if (!type_match) {
        cli::cli_abort(c(
          "Parameter '{p_name}' has incorrect type for schema '{resource_id}'.",
          "i" = "Expected type '{expected_type}', but got type '{class(actual_value)[1]}' for value '{.val {actual_value}}'."
        ))
        return(NA_character_)
      }
    }
  }

  # Construct filename using glue (FIXED)
  generated_filename = tryCatch(
    do.call(glue::glue, c(list(schema$filename_template, .open = "{", .close = "}"), params)),
    error = function(e) {
      cli::cli_abort(c(
        "Error constructing filename for schema '{resource_id}' with provided params.",
        "Template: '{schema$filename_template}'",
        "Params: {paste(names(params), params, sep = '=', collapse = ', ')}",
        "Original Error: {e$message}" # Include original glue error
      ))
      return(NULL)
    }
  )
  if (is.null(generated_filename)) return(NA_character_)

  # Construct resource_subpath_parts using glue (FIXED)
  generated_subpath_parts = tryCatch({
    if (is.null(schema$resource_subpath_parts_template)) {
      NULL
    } else {
      sapply(schema$resource_subpath_parts_template, function(template_part) {
        do.call(glue::glue, c(list(template_part, .open = "{", .close = "}"), params))
      }, USE.NAMES = FALSE)
    }
  }, error = function(e) {
    cli::cli_abort(c(
      "Error constructing subpath for schema '{resource_id}' with provided params.",
      "Template parts: {paste(schema$resource_subpath_parts_template, collapse = ', ')}",
      "Params: {paste(names(params), params, sep = '=', collapse = ', ')}",
      "Original Error: {e$message}" # Include original glue error
    ))
    return(NULL)
  })

  if (is.null(generated_subpath_parts) && !is.null(schema$resource_subpath_parts_template)) {
    return(NA_character_)
  }

  if (verbose) {
    cli::cli_alert_info("Using schema: {resource_id} ({schema$description})")
    cli::cli_alert_info("Generated Filename: {.file {generated_filename}}")
    if (!is.null(generated_subpath_parts) && length(generated_subpath_parts) > 0) {
      cli::cli_alert_info("Generated Subpath Parts: {paste(generated_subpath_parts, collapse = '/')}")
    } else {
      cli::cli_alert_info("Generated Subpath Parts: (none)")
    }
  }

  final_user_agent = if (!is.null(user_agent)) {
    user_agent
  } else {
    pkg_name_str = if(!is.null(current_package_name)) current_package_name else "UnknownPackage"
    pkg_version_str = tryCatch(as.character(utils::packageVersion(pkg_name_str)), error = function(e) "dev")
    if(pkg_version_str == "dev" && !is.null(current_package_name)) { # try again if it was UnknownPackage
      pkg_version_str = tryCatch(as.character(utils::packageVersion(current_package_name)), error = function(e) "dev")
    }
    paste0(pkg_name_str, "/", pkg_version_str, " (R Package; +https://your-package-url-if-any)") # Replace with actual URL if you have one
  }

  return(geosphere_download_from_filelisting(
    dest_dir = dest_dir,
    filename = generated_filename,
    resource_id = resource_id,
    resource_subpath_parts = generated_subpath_parts,
    base_data_url = base_data_url,
    user_agent = final_user_agent,
    overwrite = overwrite,
    verbose = verbose,
    timeout_seconds = timeout_seconds
  ))
}
