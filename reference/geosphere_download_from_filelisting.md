# Download HTTPS Files from Geosphere

Downloads a single file from the Geosphere Austria data hub by
constructing its URL from specified components: resource ID, optional
subpath parts within the resource, and the filename. This function is
intended for direct file downloads where the full path structure to the
file is known or can be constructed.

## Usage

``` r
geosphere_download_from_filelisting(
  dest_dir,
  filename,
  resource_id,
  resource_subpath_parts = NULL,
  base_data_url = "https://public.hub.geosphere.at/datahub/resources/",
  user_agent = "R Package (davR File Download)",
  overwrite = FALSE,
  verbose = TRUE,
  timeout_seconds = 300
)
```

## Arguments

- dest_dir:

  The directory where the downloaded file will be saved. If it doesn't
  exist, it will be created.

- filename:

  The name of the file to download (e.g.,
  "SPARTACUS2-DAILY_TX_2020.nc").

- resource_id:

  The specific resource ID (e.g., "spartacus-v2-1d-1km").

- resource_subpath_parts:

  A character vector of path segments that appear *after* the
  `resource_id` and *before* the `filename` in the URL. If `NULL`
  (default), the filename is assumed to be directly under the
  `resource_id` path.

- base_data_url:

  The base URL for accessing Geosphere Austria resource data.

- user_agent:

  Custom User-Agent string for the HTTP request.

- overwrite:

  Logical. If `TRUE`, an existing file in `dest_dir` with the same name
  will be overwritten. If `FALSE` (default), an existing file will be
  skipped.

- verbose:

  Logical. If `TRUE` (default), prints informational messages.

- timeout_seconds:

  Request timeout in seconds. Passed to
  [`httr::GET`](https://httr.r-lib.org/reference/GET.html).

## Value

The full path to the successfully downloaded or already existing file if
successful, otherwise `NA_character_` if the download failed.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a temporary directory for downloads
temp_dl_dir = tempfile("geosphere_pkg_dl_")
dir.create(temp_dl_dir)

# Example 1: Download SPARTACUS TX data for 2020
spartacus_file = geosphere_download_from_filelisting(
  dest_dir = temp_dl_dir,
  filename = "SPARTACUS2-DAILY_TX_2020.nc",
  resource_id = "spartacus-v2-1d-1km",
  verbose = TRUE
)
if (!is.na(spartacus_file)) print(paste("Downloaded:", spartacus_file))

# Example 2: Download APOLIS data with subpath
apolis_file = geosphere_download_from_filelisting(
  dest_dir = temp_dl_dir,
  filename = "APOLIS_2006_01.nc",
  resource_id = "apolis-short-daily-dir-hori",
  resource_subpath_parts = c("2006", "01"),
  verbose = TRUE
)
if (!is.na(apolis_file)) print(paste("Downloaded:", apolis_file))

# Example 3: Download VDL data with multiple subpath parts
vdl_file = geosphere_download_from_filelisting(
  dest_dir = temp_dl_dir,
  filename = "t2m_2022_01_15.nc",
  resource_id = "vdl-standard-v1-1h-1km-era5land-downscaled",
  resource_subpath_parts = c("2022", "01", "15", "t2m"),
  verbose = TRUE
)
if (!is.na(vdl_file)) print(paste("Downloaded:", vdl_file))

# Clean up
unlink(temp_dl_dir, recursive = TRUE)
} # }
```
