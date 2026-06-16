% Generated manually; run devtools::document() to refresh.

\name{kba_neuzulassungen}
\alias{kba_neuzulassungen}
\title{KBA FZ28 – monatliche Neuzulassungen (alternative Antriebe)}
\usage{
kba_neuzulassungen(
  type = c(
    "pkw_bundeslaender",
    "pkw_monate",
    "kfz_fahrzeugarten",
    "pkw_halter",
    "pkw_marken",
    "pkw_marken_jahr",
    "pkw_segmente"
  ),
  file = NULL,
  dir = NULL,
  verbose = TRUE,
  page_url = "https://www.kba.de/DE/Statistik/Produktkatalog/produkte/Fahrzeuge/fz28/fz28_gentab.html?nn=835828",
  zeitraum = c("monat", "jahr_bisher", "alle")
)
}
\arguments{
\item{type}{Auswertung / Tabellenblatt.}
\item{file}{Lokale Monatsdatei `fz28_YYYY_MM.xlsx`.}
\item{dir}{Verzeichnis mit mehreren FZ28-Dateien.}
\item{verbose}{Fortschrittsmeldungen.}
\item{page_url}{KBA-Downloadseite.}
\item{zeitraum}{Bei Sheets mit Monats- und Jahresblock (z. B. FZ 28.9).}
}
\value{
Tibble mit u. a. \code{berichtsmonat}, \code{zeitraum}, Zählwerten und
Anteilen für alternative Antriebe (BEV, PHEV, \ldots).
}
\description{
Liest KBA FZ28-Excel-Dateien (monatliche Neuzulassungen mit alternativen
Antrieben). Bundesländer, PKW-Monate, Marken, Segmente u. a.
}
\examples{
\dontrun{
kba_neuzulassungen("pkw_bundeslaender")
kba_download_fz28(dir = "kba_fz28")
}
}
