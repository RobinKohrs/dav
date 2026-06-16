# KBA FZ28 – monatliche Neuzulassungen (alternative Antriebe)

Liest KBA FZ28-Excel-Dateien (monatliche Neuzulassungen mit alternativen
Antrieben). Bundesländer, PKW-Monate, Marken, Segmente u. a.

## Usage

``` r
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
```

## Arguments

- type:

  Auswertung / Tabellenblatt.

- file:

  Lokale Monatsdatei \`fz28_YYYY_MM.xlsx\`.

- dir:

  Verzeichnis mit mehreren FZ28-Dateien.

- verbose:

  Fortschrittsmeldungen.

- page_url:

  KBA-Downloadseite.

- zeitraum:

  Bei Sheets mit Monats- und Jahresblock (z. B. FZ 28.9).

## Value

Tibble mit u. a. `berichtsmonat`, `zeitraum`, Zählwerten und Anteilen
für alternative Antriebe (BEV, PHEV, ...).

## Examples

``` r
if (FALSE) { # \dontrun{
kba_neuzulassungen("pkw_bundeslaender")
kba_download_fz28(dir = "kba_fz28")
} # }
```
