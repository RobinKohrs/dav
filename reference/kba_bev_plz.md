# BEV-Bestand nach PLZ

BEV-Bestand nach PLZ

## Usage

``` r
kba_bev_plz(
  halter = c("alle", "privat", "gewerblich"),
  file = NULL,
  dir = NULL,
  ...
)
```

## Arguments

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

Tibble mit `stichtag`, `plz`, `halter`, `bev_bestand`, `phev_bestand`
