# Zeitreihe über mehrere Quartale (nur für Bundesland/Kreis)

Zeitreihe über mehrere Quartale (nur für Bundesland/Kreis)

## Usage

``` r
kba_zeitreihe(
  geo = c("bundesland", "kreis"),
  antrieb = c("bev", "phev", "hybrid", "gas", "diesel"),
  dir = NULL,
  ...
)
```

## Arguments

- geo:

  "bundesland" oder "kreis"

- antrieb:

  "bev", "phev", "hybrid", "gas", "diesel"

- dir:

  Verzeichnis mit mehreren Dateien (erforderlich)

- ...:

  weitere Argumente an `kba_bestand`

## Value

Tibble mit `stichtag`, `geo_code`, `geo_name`, `bestand`
