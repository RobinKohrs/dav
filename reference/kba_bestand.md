# KBA FZ27 Bestand – Fahrzeugbestand nach verschiedenen Merkmalen

Liest eine lokale KBA FZ27-Excel-Datei ein (Quartalsdaten, Bestand an
Kraftfahrzeugen) und gibt die gewünschten Daten als aufgeräumtes Tibble
zurück. Wird kein `file` angegeben, wird automatisch die aktuellste
Datei von der KBA-Website heruntergeladen.

## Usage

``` r
kba_bestand(
  type = c("bundesland", "bundesland_kraftstoff", "pkw_quartale", "pkw_marken",
    "pkw_segmente", "pkw_halter", "pkw_emissionen", "kfz_emissionen",
    "nutzfahrzeuge_gewicht", "kfz_alter", "pkw_kreise", "pkw_plz", "pkw_gemeinden"),
  file = NULL,
  dir = NULL,
  verbose = TRUE,
  page_url = .KBA_FZ27_PAGE_URL
)
```

## Arguments

- type:

  Character. Auswahl der Auswertung.

- file:

  Character oder `NULL`. Pfad zu einer lokalen Excel-Datei.

- dir:

  Character oder `NULL`. Verzeichnis mit mehreren Dateien.

- verbose:

  Logical. Fortschrittsmeldungen.

- page_url:

  URL der KBA-Übersichtsseite.

## Value

Tibble mit den angeforderten Daten.
