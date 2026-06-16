# Alle KBA FZ28-Excel-Dateien herunterladen

Lädt alle auf der KBA-FZ28-Seite verlinkten Monats-Excel-Dateien
herunter.

## Usage

``` r
kba_download_fz28(
  dir = "kba_fz28",
  overwrite = FALSE,
  verbose = TRUE,
  page_url = "https://www.kba.de/DE/Statistik/Produktkatalog/produkte/Fahrzeuge/fz28/fz28_gentab.html?nn=835828"
)
```

## Arguments

- dir:

  Zielverzeichnis.

- overwrite:

  Bestehende Dateien überschreiben?

- verbose:

  Fortschrittsmeldungen.

- page_url:

  KBA-Übersichtsseite.

## Value

Invisible character vector of downloaded file paths.

## Examples

``` r
if (FALSE) { # \dontrun{
kba_download_fz28(dir = "kba_fz28")
} # }
```
