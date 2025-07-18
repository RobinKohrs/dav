% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/geosphere_get_data.R
\name{geosphere_get_data}
\alias{geosphere_get_data}
\title{Get data from Geosphere Austria's Open Data Hub}
\usage{
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
}
\arguments{
\item{resource_id}{Required dataset ID.}

\item{parameters}{Optional parameter IDs.}

\item{start}{Optional start date/time string.}

\item{end}{Optional end date/time string.}

\item{station_ids}{Optional station IDs.}

\item{output_format}{API output format (e.g., "csv").}

\item{return_format}{R function return: "file", "dataframe", "raw".}

\item{output_file}{Path for \code{return_format = "file"}.}

\item{verbose}{If \code{TRUE}, prints "Requesting URL" message. Key success/fail messages always print.}

\item{print_url}{If \code{TRUE}, prints the full URL that will be requested.}

\item{debug}{Print detailed debug messages?}

\item{timeout_seconds}{Request timeout.}

\item{...}{Additional API query parameters.}

\item{api_url}{Base API URL.}

\item{version}{API version (e.g., "v1").}

\item{type}{API data type (e.g., "timeseries").}

\item{mode}{API data mode (e.g., "historical").}
}
\value{
Path, data frame, or httr response; NULL on failure.
}
\description{
Fetches data from Geosphere API. Handles common parameters and returns data
as a file path, data frame, or raw response. Returns NULL on failure.
Provides a single concluding success or failure message with emoji.
If verbose=TRUE, prints the Requesting URL, then the single concluding message.
}
