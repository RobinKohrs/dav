# Explore Geosphere Resource Metadata and Requirements

Fetches metadata and determines required query parameters for a specific
Geosphere resource ID across all its available type, mode, and format
combinations. It presents available parameters, coverage details, and
the definitive required parameters needed to query the data endpoint via
`geosphere_get_data`.

## Usage

``` r
geosphere_explore_resource(
  resource_id,
  api_url = "https://dataset.api.hub.geosphere.at",
  version = "v1",
  user_agent = "davR",
  print_summary = TRUE,
  timeout_seconds = 2
)
```

## Arguments

- resource_id:

  Character string. The specific dataset or resource ID. Required.

- api_url:

  Base URL for the Geosphere API. Defaults to Geosphere Hub v1.

- version:

  API version string. Defaults to "v1".

- user_agent:

  A string to identify the client. Defaults to "davR".

- print_summary:

  Logical. If `TRUE` (default), print a formatted summary to the console
  for each combination found.

- timeout_seconds:

  Numeric. Timeout in seconds for HTTP requests. Defaults to 2.

## Value

A named list where each element corresponds to a unique combination of
`type`, `mode`, and `response_formats` found for the `resource_id`. The
name of each element is a descriptive string like
`"station_historical_csv"`. Each element is itself a list containing:

- combination:

  A list detailing the specific type, mode, and formats.

- metadata:

  The full raw metadata list fetched from the API's `/metadata` endpoint
  (or NULL if failed).

- available_parameters:

  A data frame (tibble) of available parameters (if found in metadata).

- time_coverage:

  A list indicating start/end times (if found in metadata).

- spatial_info:

  A list with spatial details (CRS, bbox, etc.) (if found in metadata).

- required_query_params:

  A character vector listing the query parameters identified as required
  by probing the data endpoint (or NULL if determination failed).

Returns `NULL` if the initial dataset lookup fails or the `resource_id`
is not found.

## Details

This function first retrieves the list of all available datasets using
`geosphere_get_datasets`. It then filters for the specified
`resource_id`. For each unique combination of type, mode, and format
found for that ID, it retrieves descriptive metadata (available
parameters, time range, etc.) from the resource's `/metadata` endpoint
via direct HTTP calls. Finally, for each combination, it makes a
deliberate (parameter-less) request to the main *data* endpoint to
provoke an error message. By parsing this error message (typically JSON
with a 'detail' field), it accurately identifies the query parameters
that the API requires for that specific data endpoint. Requires
`geosphere_get_datasets` function to be available.

## Examples

``` r
if (FALSE) { # \dontrun{
# Requires geosphere_get_datasets to be available

# Explore a resource known to have multiple combinations
exploration_results = geosphere_explore_resource(
  resource_id = "apolis_short-v1-1d-100m"
)

# The function prints summaries by default.
# The returned object is a list named by combinations:
print(names(exploration_results))
# > [1] "grid_historical_geojson"      "grid_historical_netcdf" ...

# Inspect the details for one specific combination:
if ("grid_historical_geojson" %in% names(exploration_results)) {
   # Check the *required* parameters found by probing the data endpoint:
   print(exploration_results$grid_historical_geojson$required_query_params)
   # Should show: [1] "parameters" "start" "end" "bbox" (based on example error)

   # Compare with *available* parameters from metadata:
   print(utils::head(exploration_results$grid_historical_geojson$available_parameters))
}

# Explore a resource with likely only one combination
exploration_klima = geosphere_explore_resource(resource_id = "klima-v2-1h")
if (!is.null(exploration_klima)) {
   print(names(exploration_klima))
   # Likely "station_historical_csv" or similar
   print(exploration_klima[[1]]$required_query_params)
   # Should show something like "parameters", "start", "end", "station_ids"
}
} # }
```
