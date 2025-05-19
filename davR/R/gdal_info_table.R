#' Extract and Select Subdataset Information from a Raster File
#'
#' Uses `gdalUtilities::gdalinfo` with JSON output to extract subdataset #' information into a tidy data frame. Optionally allows interactive selection.  #'
#' @description
#' This function runs `gdalUtilities::gdalinfo(file, json = TRUE)` to get
#' structured information about a raster file, specifically extracting details
#' about any subdatasets (common in formats like NetCDF or HDF). It parses
#' the subdataset name and description fields to create a summary table.
#'
#' @param file Character string. Path to the raster file (e.g., NetCDF, HDF).
#' @param interactive Logical. If `TRUE` and the session is interactive, prompts
#'   the user to select subdatasets via a graphical list (if available) or
#'   text menu. Default: `FALSE`.
#' @param ... Additional arguments passed verbatim to `gdalUtilities::gdalinfo()`.
#'        Note that `json = TRUE` is automatically added.
#'
#' @return A list with two elements:
#'   \item{table}{A data frame containing information for each subdataset found,
#'     with columns typically including `index`, `name` (full GDAL name),
#'     `variable` (derived variable name), `description`, `dimensions`, and
#'     `data_type`. Returns an empty data frame with these columns if no
#'     subdatasets are found.}
#'   \item{selected}{A character vector containing the `variable` names of the
#'     subdatasets selected by the user. Empty if `interactive = FALSE` or
#'     no selection is made.}
#'
#' @export
#' @importFrom gdalUtilities gdalinfo
#' @importFrom utils select.list packageVersion sessionInfo
#' @importFrom tools file_path_sans_ext
#' @importFrom stats setNames
#'
#' @examples
#' \dontrun{
#' # Create a dummy NetCDF file for demonstration if needed
#' # (Requires the ncdf4 package)
#' if (requireNamespace("ncdf4", quietly = TRUE)) {
#'   tmp_nc_file = tempfile(fileext = ".nc")
#'   dimX = ncdf4::ncdim_def("x", "meters", 1:10)
#'   dimY = ncdf4::ncdim_def("y", "meters", 1:5)
#'   var1 = ncdf4::ncvar_def("temp", "degrees_C", list(dimX, dimY), -999,
#'                           "Temperature variable")
#'   var2 = ncdf4::ncvar_def("precip", "mm", list(dimX, dimY), -999,
#'                           "Precipitation variable")
#'   nc_out = ncdf4::nc_create(tmp_nc_file, list(var1, var2))
#'   ncdf4::nc_close(nc_out)
#'
#'   # --- Example Usage ---
#'
#'   # 1. Extract subdataset table (non-interactive)
#'   info_list = gdal_info_table(tmp_nc_file)
#'   print(info_list$table)
#'
#'   # 2. Extract and potentially select interactively
#'   # (Will only prompt if run in an interactive R session)
#'   selected_info = gdal_info_table(tmp_nc_file, interactive = TRUE)
#'   if (length(selected_info$selected) > 0) {
#'     cat("\nSelected variables:\n")
#'     print(selected_info$selected)
#'   } else if (interactive()) {
#'     cat("\nNo variables selected interactively.\n")
#'   }
#'
#'   # Clean up dummy file
#'   unlink(tmp_nc_file)
#' } else {
#'   message("Skipping examples: ncdf4 package not available to create test file.")
#' }
#'
#' # Example with a potentially non-existent file (will error)
#' try(gdal_info_table("non_existent_file.nc"))
#' }
gdal_get_subdataset_table = function(file, interactive = FALSE, ...) {
  # --- 1. Input Validation and Dependency Checks ---
  if (!is.character(file) || length(file) != 1 || nchar(file) == 0) {
    stop("'file' must be a non-empty character string.", call. = FALSE)
  }
  if (!file.exists(file)) {
    stop("File not found: '", file, "'", call. = FALSE)
  }
  if (!is.logical(interactive) || length(interactive) != 1) {
    stop(
      "'interactive' must be a single logical value (TRUE/FALSE).",
      call. = FALSE
    )
  }

  # Check for gdalUtilities (listed in Imports, so should be present if pkg installed)
  # Redundant check usually not needed if Imports handled correctly, but safe.
  if (!requireNamespace("gdalUtilities", quietly = TRUE)) {
    # This error should ideally not be reached if package dependencies are correct
    stop(
      "Package 'gdalUtilities' is required but not found. Please install it.",
      call. = FALSE
    )
  }

  # Define the structure of the output data frame for consistency
  empty_df = data.frame(
    index = integer(),
    name = character(),
    variable = character(),
    description = character(),
    dimensions = character(),
    data_type = character(),
    stringsAsFactors = FALSE
  )

  # --- 2. Run gdalinfo with JSON output ---
  gdalinfo_output = tryCatch(
    {
      gdalUtilities::gdalinfo(file, json = TRUE, ...) # Force JSON output
    },
    error = function(e) {
      stop(
        "gdalUtilities::gdalinfo failed for file '",
        file,
        "'.\n  Original error: ",
        e$message,
        call. = FALSE
      )
    }
  )

  # --- 3. Extract Subdatasets from JSON structure ---
  subdatasets_list = gdalinfo_output$subdatasets

  if (is.null(subdatasets_list) || length(subdatasets_list) == 0) {
    warning("No subdatasets found in '", file, "'.", call. = FALSE)
    return(list(table = empty_df, selected = character(0)))
  }

  # --- 4. Parse Subdataset Information ---
  # Extract names (e.g., "subdataset_1") and corresponding data
  sds_names = names(subdatasets_list)
  sds_data = unname(subdatasets_list) # Get list of lists without top-level names

  # Pre-allocate lists to store extracted info
  indices = integer(length(sds_data))
  full_names = character(length(sds_data))
  descriptions = character(length(sds_data))
  variables = character(length(sds_data))
  dimensions = character(length(sds_data))
  data_types = character(length(sds_data))

  parse_error = FALSE
  for (i in seq_along(sds_data)) {
    # Extract index number from the name (e.g., "subdataset_1")
    indices[i] = as.integer(gsub("subdataset_", "", sds_names[i]))

    # Extract full GDAL name (e.g., "NETCDF:\"file.nc\":variable")
    full_names[i] = sds_data[[i]]$ds_name %||% NA_character_ # Use %||% helper below for NULL safety

    # Extract description string (e.g., "[10x20] Description (DataType)")
    raw_desc = sds_data[[i]]$ds_desc %||% NA_character_
    descriptions[i] = raw_desc # Store raw description initially

    # Attempt to parse variable, dimensions, description part, data type from ds_name and ds_desc
    # Variable Name: Often the part after the last colon in ds_name
    variables[i] = gsub(".*:", "", full_names[i]) %||% NA_character_

    # Parse dimensions, description, type from ds_desc using regex
    # Example: "[10x5] Air Temperature (Float32)"
    # regex = "^\\[([^\\]]*)\\][[:space:]]*([^\\(]*)[[:space:]]*\\(([^\\)]*)\\)$" # Original stricter
    regex = "^\\[([^\\]]*)\\][[:space:]]*(.*?)[[:space:]]*\\(([^\\)]+)\\)[[:space:]]*$" # More flexible spacing/content

    match_result = regexec(regex, raw_desc)

    if (!is.na(raw_desc) && match_result[[1]][1] != -1) {
      parts = regmatches(raw_desc, match_result)[[1]]
      # parts[1] is full match, [2] is dims, [3] is desc, [4] is type
      dimensions[i] = trimws(parts[2])
      descriptions[i] = trimws(parts[3]) # Overwrite raw_desc with parsed description
      data_types[i] = trimws(parts[4])
    } else {
      # If regex fails, store NA or make best guess
      dimensions[i] = NA_character_
      data_types[i] = NA_character_
      # Keep the raw description if parsing fails, maybe warn once?
      if (!is.na(raw_desc) && nchar(raw_desc) > 0 && !parse_error) {
        warning(
          "Could not fully parse description string for at least one subdataset: '",
          raw_desc,
          "'. Storing raw description.",
          call. = FALSE
        )
        parse_error = TRUE # Show warning only once
      }
      # If name parsing also failed, variable might be NA here too
    }
  }

  # --- 5. Create Data Frame ---
  subdatasets_df = data.frame(
    index = indices,
    name = full_names,
    variable = variables,
    description = descriptions,
    dimensions = dimensions,
    data_type = data_types,
    stringsAsFactors = FALSE
  )

  # Sort by index just in case JSON order wasn't numeric
  subdatasets_df = subdatasets_df[order(subdatasets_df$index), , drop = FALSE]
  rownames(subdatasets_df) = NULL # Reset row names

  # --- 6. Interactive Selection ---
  selected_vars = character(0) # Default empty selection

  # Proceed only if interactive=TRUE, session is interactive, and there are datasets
  if (interactive && base::interactive() && nrow(subdatasets_df) > 0) {
    # Create display strings: "Index: Variable (Description)"
    display_info = sprintf(
      "%d: %s (%s)",
      subdatasets_df$index,
      subdatasets_df$variable,
      subdatasets_df$description
    )
    names(display_info) = subdatasets_df$index # Use index as names for easier mapping back

    cat("Available subdatasets:\n") # Provide context before menu pops up
    selected_indices_str = tryCatch(
      {
        utils::select.list(
          display_info,
          title = "Select subdatasets (use spacebar/click, Enter when done)",
          multiple = TRUE,
          graphics = getOption("menu.graphics", TRUE) # Use graphical if available
        )
      },
      error = function(e) {
        warning(
          "Could not display interactive selection menu: ",
          e$message,
          call. = FALSE
        )
        character(0) # Return empty on error
      }
    )

    if (length(selected_indices_str) > 0) {
      # Map selection back to indices (using names we set)
      selected_idx = as.integer(names(display_info)[match(
        selected_indices_str,
        display_info
      )])
      # Get the corresponding variable names
      selected_vars = subdatasets_df$variable[match(
        selected_idx,
        subdatasets_df$index
      )]
    }
  } else if (interactive && !base::interactive()) {
    warning(
      "'interactive = TRUE' but R session is not interactive. Skipping selection.",
      call. = FALSE
    )
  }

  # --- 7. Return Results ---
  return(list(
    table = subdatasets_df,
    selected = selected_vars
  ))
}

# Helper function for concise NULL/NA checks (similar to purrr::%||%)
# If x is NULL, return y, otherwise return x.
`%||%` = function(x, y) {
  if (is.null(x)) y else x
}
