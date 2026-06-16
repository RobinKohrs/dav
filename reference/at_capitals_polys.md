# Polygons for Austria's 9 State Capitals

Spatial polygon data for Austria’s 9 Landeshauptstädte (state capitals),
filtered from the official Statistik Austria municipal boundaries
shapefile.

## Format

An `sf` object with 9 rows and X columns (see below).

## Source

Statistik Austria:
<https://data.statistik.gv.at/data/OGDEXT_GEM_1_STATISTIK_AUSTRIA_20250101.zip>

## Details

The data was filtered using the official municipality codes (GKZ) for
the following capitals: Wien, St. Pölten, Eisenstadt, Linz, Graz,
Klagenfurt am Wörthersee, Salzburg, Innsbruck, Bregenz.

## See also

The full shapefile was obtained from Statistik Austria's open data
portal.

## Examples

``` r
plot(at_capitals_polys["geometry"])
#> Error in x[i]: Can't subset columns that don't exist.
#> ✖ Column `geometry` doesn't exist.
```
