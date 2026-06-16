# SUV- und Geländewagen-Anteil (Proxy für Gewichtszunahme)

SUV- und Geländewagen-Anteil (Proxy für Gewichtszunahme)

## Usage

``` r
kba_suv_anteil(file = NULL, dir = NULL, ...)
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

Tibble mit `stichtag`, `suv_gelaende_anteil_pct`
