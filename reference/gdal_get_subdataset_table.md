# Extract and Select Subdataset Information from a Raster File

This function runs `gdalUtilities::gdalinfo(file, json = TRUE)` to get
structured information about a raster file, specifically extracting
details about any subdatasets (common in formats like NetCDF or HDF). It
parses the subdataset name and description fields to create a summary
table.

## Usage

``` r
gdal_get_subdataset_table(file, interactive = FALSE, ...)
```

## Arguments

- file:

  Character string. Path to the raster file (e.g., NetCDF, HDF).

- interactive:

  Logical. If `TRUE` and the session is interactive, prompts the user to
  select subdatasets via a graphical list (if available) or text menu.
  Default: `FALSE`.

- ...:

  Additional arguments passed verbatim to
  [`gdalUtilities::gdalinfo()`](https://rdrr.io/pkg/gdalUtilities/man/gdalinfo.html).
  Note that `json = TRUE` is automatically added.

## Value

A list with two elements:

- table:

  A data frame containing information for each subdataset found, with
  columns typically including `index`, `name` (full GDAL name),
  `variable` (derived variable name), `description`, `dimensions`, and
  `data_type`. Returns an empty data frame with these columns if no
  subdatasets are found.

- selected:

  A character vector containing the `variable` names of the subdatasets
  selected by the user. Empty if `interactive = FALSE` or no selection
  is made.

## Details

Uses
[`gdalUtilities::gdalinfo`](https://rdrr.io/pkg/gdalUtilities/man/gdalinfo.html)
with JSON output to extract subdataset \#' information into a tidy data
frame. Optionally allows interactive selection. \#'

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a dummy NetCDF file for demonstration if needed
# (Requires the ncdf4 package)
if (requireNamespace("ncdf4", quietly = TRUE)) {
  tmp_nc_file = tempfile(fileext = ".nc")
  dimX = ncdf4::ncdim_def("x", "meters", 1:10)
  dimY = ncdf4::ncdim_def("y", "meters", 1:5)
  var1 = ncdf4::ncvar_def("temp", "degrees_C", list(dimX, dimY), -999,
                          "Temperature variable")
  var2 = ncdf4::ncvar_def("precip", "mm", list(dimX, dimY), -999,
                          "Precipitation variable")
  nc_out = ncdf4::nc_create(tmp_nc_file, list(var1, var2))
  ncdf4::nc_close(nc_out)

  # --- Example Usage ---

  # 1. Extract subdataset table (non-interactive)
  info_list = gdal_info_table(tmp_nc_file)
  print(info_list$table)

  # 2. Extract and potentially select interactively
  # (Will only prompt if run in an interactive R session)
  selected_info = gdal_info_table(tmp_nc_file, interactive = TRUE)
  if (length(selected_info$selected) > 0) {
    cat("\nSelected variables:\n")
    print(selected_info$selected)
  } else if (interactive()) {
    cat("\nNo variables selected interactively.\n")
  }

  # Clean up dummy file
  unlink(tmp_nc_file)
} else {
  message("Skipping examples: ncdf4 package not available to create test file.")
}

# Example with a potentially non-existent file (will error)
try(gdal_info_table("non_existent_file.nc"))
} # }
```
