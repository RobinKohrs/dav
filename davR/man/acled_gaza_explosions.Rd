% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/acled_gaza_explosions.R
\name{acled_gaza_explosions}
\alias{acled_gaza_explosions}
\title{Download ACLED Data for Explosion Events in the Gaza Strip}
\usage{
acled_gaza_explosions(
  email_address = NULL,
  access_key = NULL,
  start_date,
  end_date,
  sub_event_types = NULL,
  page_limit = 5000,
  max_pages = 100,
  output_format = "df",
  ...
)
}
\arguments{
\item{email_address}{Your registered ACLED API email address.
If \code{NULL} or missing, uses \code{ACLED_EMAIL} env var.}

\item{access_key}{Your ACLED API access key.
If \code{NULL} or missing, uses \code{ACLED_API_KEY} env var.}

\item{start_date}{Character string or Date object. Start date (YYYY-MM-DD). Required.}

\item{end_date}{Character string or Date object. End date (YYYY-MM-DD). Required.}

\item{sub_event_types}{Character vector. Optional. Specific sub-event type(s)
under "Explosions/Remote violence" to filter by.
If \code{NULL} (default), all "Explosions/Remote violence" events are included.
Example: \code{c("Air/drone strike", "Shelling/artillery/missile attack")}.}

\item{page_limit}{Numeric. Records per API page request.}

\item{max_pages}{Numeric. Maximum pages to fetch to prevent overly long requests.}

\item{output_format}{Character. "df" for a data.frame or "raw_json" for raw list.}

\item{...}{Additional arguments to be passed to \code{acled_download_events}
(and subsequently to the ACLED API).}
}
\value{
A data.frame containing the queried ACLED event data (if \code{output_format = "df"}),
or a list of parsed JSON content from each page (if \code{output_format = "raw_json"}).
Returns NULL if a critical error occurs or no data is found.
}
\description{
This is a specific wrapper function that calls \code{acled_download_events}
to download data for events classified as "Explosions/Remote violence"
in the Gaza Strip, Palestine.
}
\details{
Authentication credentials (email and access key) can be provided as arguments
or retrieved from environment variables \code{ACLED_EMAIL} and \code{ACLED_API_KEY}.
}
\examples{
\dontrun{
# --- Set environment variables first (recommended) ---
# Sys.setenv(ACLED_EMAIL = "YOUR_EMAIL")
# Sys.setenv(ACLED_API_KEY = "YOUR_ACCESS_KEY")

# Get all explosion events in Gaza for a specific week
gaza_explosions_week = acled_gaza_explosions(
  start_date = "2023-10-01",
  end_date = "2023-10-07"
)

if (!is.null(gaza_explosions_week) && nrow(gaza_explosions_week) > 0) {
  print(head(gaza_explosions_week[, c("event_date", "admin1", "location", "event_type", "sub_event_type")]))
  print(table(gaza_explosions_week$sub_event_type))
}

# Get only Air/drone strikes and Shelling in Gaza for a specific day
gaza_specific_strikes_day = acled_gaza_explosions(
  start_date = "2023-10-08",
  end_date = "2023-10-08",
  sub_event_types = c("Air/drone strike", "Shelling/artillery/missile attack")
)

if (!is.null(gaza_specific_strikes_day) && nrow(gaza_specific_strikes_day) > 0) {
  print(table(gaza_specific_strikes_day$sub_event_type))
}
}
}
\seealso{
\code{\link[=acled_download_events]{acled_download_events()}}
}
