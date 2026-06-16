# Absoluter BEV-Bestand

Absoluter BEV-Bestand

## Usage

``` r
kba_bev_n(
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

Tibble mit `bev_n`
