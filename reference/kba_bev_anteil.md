# BEV-Anteil (%)

BEV-Anteil (%)

## Usage

``` r
kba_bev_anteil(
  geo = c("bundesland", "kreis", "plz", "gemeinde"),
  halter = c("alle", "privat", "gewerblich"),
  file = NULL,
  dir = NULL,
  ...
)
```

## Arguments

- geo:

  "bundesland", "kreis", "plz", "gemeinde"

- halter:

  "alle", "privat", "gewerblich" (nur für PLZ/Gemeinde)

- file:

  Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).

- dir:

  Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).

- ...:

  Weitere Argumente an
  [`kba_bestand()`](https://robinkohrs.github.io/dav/reference/kba_bestand.md).

## Value

Tibble mit zusätzlicher Spalte `bev_anteil_pct`
