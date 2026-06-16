# Download File Using a Predefined Geosphere Schema

Constructs the filename and subpath based on a predefined internal
schema for a given Geosphere Austria `resource_id` and a set of
parameters, then downloads the file. This is an internal helper function
for downloading known datasets.

## Usage

``` r
geosphere_download_from_schema(
  dest_dir,
  resource_id,
  params,
  base_data_url = "https://public.hub.geosphere.at/datahub/resources/",
  user_agent = NULL,
  overwrite = FALSE,
  verbose = TRUE,
  timeout_seconds = 300
)
```

## Arguments

- dest_dir:

  Directory to save the file.

- resource_id:

  The key in the internal schemas list corresponding to the dataset
  (e.g., "spartacus-v2-1d-1km"). This is also the `resource_id` used in
  the URL.

- params:

  A named list of parameter values to fill into the templates (e.g.,
  `list(year = 2020, variable_type = "TX")`).

- base_data_url:

  Base URL for Geosphere data.

- user_agent:

  Custom User-Agent. If `NULL`, a default package user agent is used.

- overwrite:

  Logical, whether to overwrite existing files.

- verbose:

  Logical, for verbose output.

- timeout_seconds:

  Request timeout.

## Value

Path to the downloaded file or `NA_character_` on failure.
