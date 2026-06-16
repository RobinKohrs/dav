# Get data from Geosphere Austria's Open Data Hub

Fetches data from Geosphere API. Handles common parameters and returns
data as a file path, data frame, or raw response. Returns NULL on
failure. Provides a single concluding success or failure message with
emoji. If verbose=TRUE, prints the Requesting URL, then the single
concluding message.

## Usage

``` r
geosphere_get_data(
  resource_id,
  parameters = NULL,
  start = NULL,
  end = NULL,
  station_ids = NULL,
  output_format = "csv",
  return_format = c("file", "dataframe", "raw"),
  output_file = NULL,
  verbose = FALSE,
  print_url = FALSE,
  debug = FALSE,
  timeout_seconds = 30,
  ...,
  api_url = "https://dataset.api.hub.geosphere.at",
  version = "v1",
  type = "timeseries",
  mode = "historical"
)
```

## Arguments

- resource_id:

  Required dataset ID.

- parameters:

  Optional parameter IDs.

- start:

  Optional start date/time string.

- end:

  Optional end date/time string.

- station_ids:

  Optional station IDs.

- output_format:

  API output format (e.g., "csv").

- return_format:

  R function return: "file", "dataframe", "raw".

- output_file:

  Path for `return_format = "file"`.

- verbose:

  If `TRUE`, prints "Requesting URL" message. Key success/fail messages
  always print.

- print_url:

  If `TRUE`, prints the full URL that will be requested.

- debug:

  Print detailed debug messages?

- timeout_seconds:

  Request timeout.

- ...:

  Additional API query parameters.

- api_url:

  Base API URL.

- version:

  API version (e.g., "v1").

- type:

  API data type (e.g., "timeseries").

- mode:

  API data mode (e.g., "historical").

## Value

Path, data frame, or httr response; NULL on failure.
