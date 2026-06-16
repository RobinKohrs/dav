# Absoluter Nicht-BEV-Bestand (alle PKW ohne reine Elektro)

Absoluter Nicht-BEV-Bestand (alle PKW ohne reine Elektro)

## Usage

``` r
kba_non_bev_n(
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

  "alle", "privat", "gewerblich" (nur PLZ/Gemeinde)

- file, dir, ...:

  weitergereicht an
  [`kba_bestand()`](https://robinkohrs.github.io/dav/reference/kba_bestand.md)

## Value

Tibble mit `nicht_bev_n` (= pkw_insgesamt - bev_n, inkl.
PHEV/Hybrid/Verbrenner)
