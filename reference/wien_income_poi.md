# Poles of Inaccessibility for Vienna Zählbezirke

A point dataset containing the pole of inaccessibility (the point
furthest from any boundary) for each Zählbezirk (census district) in
Vienna. Used by
[`statistik_get_zsp_einkommen()`](https://robinkohrs.github.io/dav/reference/statistik_get_zsp_einkommen.md)
to target WMS queries precisely inside each district.

## Format

An `sf` object with one row per Zählbezirk and the following columns:

- ZGEB:

  Character. The Zählgebiet code identifying the Zählbezirk.

- geometry:

  Point geometry in EPSG:3857 (WGS 84 / Pseudo-Mercator).

## Source

Computed from Statistik Austria Zählbezirk polygon boundaries.

## See also

[`statistik_get_zsp_einkommen()`](https://robinkohrs.github.io/dav/reference/statistik_get_zsp_einkommen.md)

## Examples

``` r
plot(wien_income_poi["geometry"])

```
