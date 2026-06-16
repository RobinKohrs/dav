% Generated manually; run devtools::document() to refresh.

\name{kba_download_fz28}
\alias{kba_download_fz28}
\title{Alle KBA FZ28-Excel-Dateien herunterladen}
\usage{
kba_download_fz28(
  dir = "kba_fz28",
  overwrite = FALSE,
  verbose = TRUE,
  page_url = "https://www.kba.de/DE/Statistik/Produktkatalog/produkte/Fahrzeuge/fz28/fz28_gentab.html?nn=835828"
)
}
\arguments{
\item{dir}{Zielverzeichnis.}
\item{overwrite}{Bestehende Dateien überschreiben?}
\item{verbose}{Fortschrittsmeldungen.}
\item{page_url}{KBA-Übersichtsseite.}
}
\value{
Invisible character vector of downloaded file paths.
}
\description{
Lädt alle auf der KBA-FZ28-Seite verlinkten Monats-Excel-Dateien herunter.}
\examples{
\dontrun{
kba_download_fz28(dir = "kba_fz28")
}
}
