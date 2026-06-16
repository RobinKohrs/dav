# Antriebsmix für eine Fahrzeugart (alle Kfz)

Antriebsmix für eine Fahrzeugart (alle Kfz)

## Usage

``` r
kba_antriebsmix(
  fahrzeugart = "Personenkraftwagen",
  bundesland = NULL,
  file = NULL,
  dir = NULL,
  ...
)
```

## Arguments

- fahrzeugart:

  Eine der Fahrzeugarten aus FZ 27.2, z.B. "Personenkraftwagen"

- bundesland:

  Optional einschränken.

- file:

  Pfad zu einer lokalen Excel-Datei (oder `NULL` für Auto-Download).

- dir:

  Verzeichnis mit mehreren Quartalsdateien (für Zeitreihen).

- ...:

  Weitere Argumente an
  [`kba_bestand()`](https://robinkohrs.github.io/dav/reference/kba_bestand.md).

## Value

Tibble mit `stichtag`, `bundesland`, `kraftstoffart`, `anzahl`
