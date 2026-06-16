# BEV-Bestand nach Kreisen (spezialisiert)

BEV-Bestand nach Kreisen (spezialisiert)

## Usage

``` r
kba_bev_kreise(file = NULL, dir = NULL, ...)
```

## Arguments

- file:

  Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).

- dir:

  Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).

- ...:

  Weitere Argumente an
  [`kba_bestand()`](https://robinkohrs.github.io/dav/reference/kba_bestand.md).

## Value

Tibble mit `stichtag`, `kreis_schluessel`, `zulassungsbezirk`,
`bundesland`, `bev_bestand`
