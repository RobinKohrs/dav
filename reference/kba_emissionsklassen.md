# Emissionsklassen (Euro-Normen) für PKW

Emissionsklassen (Euro-Normen) für PKW

## Usage

``` r
kba_emissionsklassen(bundesland = NULL, file = NULL, dir = NULL, ...)
```

## Arguments

- bundesland:

  Optional einschränken auf ein Bundesland.

- file:

  Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).

- dir:

  Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).

- ...:

  Weitere Argumente an
  [`kba_bestand()`](https://robinkohrs.github.io/dav/reference/kba_bestand.md).

## Value

Tibble mit `stichtag`, `bundesland`, `kraftstoffart`, `emissionsklasse`,
`anzahl`
