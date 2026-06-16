# Get Available Parameters for a Geosphere Resource

Retrieves all available parameters for a specific Geosphere resource ID
and returns them as a clean dataframe. The function automatically
determines the correct type/mode combination for the resource.

## Usage

``` r
geosphere_get_available_resource_parameters(
  resource_id,
  type = NULL,
  mode = NULL,
  api_url = "https://dataset.api.hub.geosphere.at",
  version = "v1",
  user_agent = "davR"
)
```

## Arguments

- resource_id:

  Character string. The specific dataset or resource ID (e.g.,
  "klima-v2-1d", "klima-v2-10min").

- type:

  Character string or `NULL`. The data type (e.g., "grid", "station").
  If `NULL` (default), the function will try to auto-detect it.

- mode:

  Character string or `NULL`. The data mode (e.g., "historical"). If
  `NULL` (default), the function will try to auto-detect it.

- api_url:

  Base URL for the Geosphere API. Defaults to Geosphere Hub v1.

- version:

  API version string. Defaults to "v1".

- user_agent:

  A string to identify the client. Defaults to "davR".

## Value

A data frame (tibble) containing all available parameters with columns:

- name:

  Parameter short name/code

- long_name:

  Descriptive parameter name

- description:

  Detailed parameter description

- unit:

  Measurement unit

- code_list_ref:

  Reference to code list (if applicable)

Returns `NULL` if the resource is not found or metadata cannot be
retrieved.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Get parameters for daily climate data
  params_daily <- geosphere_get_available_resource_parameters("klima-v2-1d")
  print(head(params_daily))

  # Get parameters for 10-minute climate data
  params_10min <- geosphere_get_available_resource_parameters("klima-v2-10min")

  # Specify type and mode explicitly if auto-detection fails
  params_explicit <- geosphere_get_available_resource_parameters(
    "klima-v2-1d",
    type = "station",
    mode = "historical"
  )
} # }
```
