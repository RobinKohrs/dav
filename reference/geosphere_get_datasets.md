# Find Available Geosphere Datasets

Retrieves and optionally filters the list of available datasets from the
Geosphere API Hub based on keywords, type, or mode.

## Usage

``` r
geosphere_get_datasets(
  url = "https://dataset.api.hub.geosphere.at/v1/datasets",
  user_agent = "davR",
  filter_keywords = NULL,
  filter_type = NULL,
  filter_mode = NULL,
  add_resource_id = TRUE
)

geosphere_find_datasets(
  url = "https://dataset.api.hub.geosphere.at/v1/datasets",
  user_agent = "davR",
  filter_keywords = NULL,
  filter_type = NULL,
  filter_mode = NULL,
  add_resource_id = TRUE
)
```

## Arguments

- url:

  URL for the datasets endpoint. Defaults to the current v1 endpoint.

- user_agent:

  Client user agent string. Defaults to "davR".

- filter_keywords:

  Character string or vector. Keep datasets whose `title` or
  `description` (if available) contain any of these keywords
  (case-insensitive).

- filter_type:

  Character string or vector. Keep datasets matching these types (e.g.,
  "grid", "station").

- filter_mode:

  Character string or vector. Keep datasets matching these modes (e.g.,
  "historical", "forecast").

- add_resource_id:

  Logical. If TRUE (default), attempt to parse the `resource_id` from
  the dataset `url` and add it as a separate column.

## Value

A data frame listing available (and potentially filtered) datasets.
Includes `metadata_url` and potentially `resource_id` columns.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Get all datasets
  all_ds = geosphere_find_datasets()
  print(head(all_ds))

  # Find historical grid datasets related to temperature or radiation
  grid_rad_ds = geosphere_find_datasets(
    filter_keywords = c("temperature", "radiation", "solar"),
    filter_type = "grid",
    filter_mode = "historical"
  )
  # Display key columns for the filtered results
  if (nrow(grid_rad_ds) > 0) {
     print(grid_rad_ds[, intersect(c("resource_id", "type", "mode", "title", "url"),
                                   names(grid_rad_ds))])
  } else {
     print("No matching datasets found.")
  }
} # }
```
