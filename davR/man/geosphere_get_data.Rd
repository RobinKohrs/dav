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
  ...,
  api_url = "https://dataset.api.hub.geosphere.at",
  version = "v1",
  type = "timeseries",
  mode = "historical",
  return_format = c("file", "dataframe", "raw"),
  output_file = NULL,
  verbose = FALSE,
  debug = FALSE,
  timeout_seconds = 120
)
}
\arguments{
\item{resource_id}{\strong{Required.} The specific dataset or resource ID (e.g., "klima-v2-1m"). Cannot be NULL or empty.}

\item{parameters}{Character vector or comma-separated string of parameter IDs to retrieve (e.g., \code{c("tl", "tx")}, \code{"tl,tx"}). Check API metadata for available parameters.}

\item{start}{Start date/time string (ISO 8601 format preferred, e.g., "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS").}

\item{end}{End date/time string (ISO 8601 format preferred).}

\item{station_ids}{Character vector or comma-separated string of station IDs (e.g., \code{c("5925", "11035")}, \code{"5925,11035"}). Check API metadata for available stations.}

\item{output_format}{The desired data format from the API (e.g., "csv", "json", "geojson"). Defaults to "csv". Passed as a query parameter.}

\item{...}{Additional query parameters specific to the API endpoint. Values will be automatically URL-encoded. Use this for less common parameters not covered by explicit arguments.}

\item{api_url}{Base URL for the Geosphere API.}

\item{version}{API version string or number (e.g., "v1", "2", 1). Defaults to "v1". Will be formatted as "vX" in the URL path.}

\item{type}{Data type (e.g., "timeseries", "station", "grid").}

\item{mode}{Data mode (e.g., "historical", "current", "forecast").}

\item{return_format}{Character string specifying the desired return type for the R function:
\itemize{
\item \code{"file"}: (Default) Downloads the data. If \code{output_file} is specified and exists, returns the path immediately. Otherwise, downloads to a temporary file (or \code{output_file}) and returns the path. Error responses are \emph{not} written to the file.
\item \code{"dataframe"}: Attempts to parse the response content (CSV or JSON) directly into a data frame or list. Requires \code{readr} and/or \code{jsonlite} packages.
\item \code{"raw"}: Returns the raw \code{httr} response object.
}}

\item{output_file}{Path where the downloaded data should be saved \emph{only} when \code{return_format = "file"}. If specified and the file exists, the download is skipped. If \code{NULL} (default), a temporary file is used for successful downloads.}

\item{verbose}{Logical. If \code{TRUE}, prints standard informational messages (using \code{cli}). Defaults to \code{FALSE}.}

\item{debug}{Logical. If \code{TRUE}, prints detailed internal debugging messages. Defaults to \code{FALSE}.}

\item{timeout_seconds}{Request timeout in seconds. Passed to \code{httr::GET}.}
}
\value{
Depends on \code{return_format}:
\itemize{
\item \code{"file"}: The path to the downloaded file (either \code{output_file} or a temporary path).
\item \code{"dataframe"}: A data frame (for CSV) or list/data frame (for JSON), parsed from the response. Requires \code{readr} or \code{jsonlite}.
\item \code{"raw"}: The raw \code{httr} response object.
}
}
\description{
Constructs a URL and fetches data from the Geosphere API's main resource endpoint
based on the provided parameters. The function allows fetching data as a file
path (default), directly into an R object (data frame), or as the raw HTTP response.

\strong{Note:} This function retrieves data from the primary resource path (e.g.,
\verb{/v1/timeseries/historical/\{resource_id\}}). To retrieve metadata (usually found
at \verb{/metadata} appended to the resource path), you would need to construct the
URL manually and use a tool like \code{httr::GET}.

See the Geosphere API documentation for details on available endpoints and parameters:
\itemize{
\item \href{https://dataset.api.hub.geosphere.at/v1/docs/getting-started.html}{Getting Started}
\item \href{https://dataset.api.hub.geosphere.at/v1/docs/user-guide/resource.html#resources}{Resources}
\item \href{https://dataset.api.hub.geosphere.at/v1/datasets}{Datasets Overview}
}
Example endpoint: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km}{SPARTACUS Monthly}
Example metadata URL: \href{https://dataset.api.hub.geosphere.at/v1/timeseries/historical/spartacus-v2-1m-1km/metadata}{SPARTACUS Monthly Metadata}
}
\examples{
\dontrun{
# Ensure necessary packages are installed
# install.packages(c("readr", "jsonlite", "cli", "httr", "glue"))

# --- Example 1: Download to a specific file, first time (verbose) ---
target_file <- "vienna_monthly_temp_2023.csv"
if(file.exists(target_file)) file.remove(target_file) # Clean up for demo

path1 <- geosphere_get_data(
    resource_id = "klima-v2-1m", parameters = "tl_mittel",
    start = "2023-01-01", end = "2023-12-31", station_ids = "11035", # Wien-Hohe Warte
    type = "station", verbose = TRUE, return_format = "file",
    output_file = target_file
)
# Prints URL, Fetching message, Writing message, Success message
print(path1)

# --- Example 2: Call again (verbose) - should skip download ---
path2 <- geosphere_get_data(
    resource_id = "klima-v2-1m", parameters = "tl_mittel",
    start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
    type = "station", verbose = TRUE, return_format = "file",
    output_file = target_file # File now exists
)
# Should only print the "already exists" message
print(path2 == path1) # Should be TRUE, same path returned

# --- Example 3: Call again (verbose=FALSE) - should print nothing ---
path3 <- geosphere_get_data(
    resource_id = "klima-v2-1m", parameters = "tl_mittel",
    start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
    type = "station", verbose = FALSE, return_format = "file",
    output_file = target_file # File now exists
)
# Should print nothing
print(path3 == path1) # Should be TRUE, same path returned

# --- Example 4: Call again (debug=TRUE) - should print debug info ---
path4 <- geosphere_get_data(
    resource_id = "klima-v2-1m", parameters = "tl_mittel",
    start = "2023-01-01", end = "2023-12-31", station_ids = "11035",
    type = "station", verbose = FALSE, debug = TRUE, return_format = "file",
    output_file = target_file # File now exists
)
# Should print all the "--- Debug: ..." messages, but not the cli messages
print(path4 == path1) # Should be TRUE

# Clean up demo file
if(file.exists(target_file)) file.remove(target_file)
}

}
