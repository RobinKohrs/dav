# Poles of Inaccessibility / Centroids for Austria-wide Zählsprengel

A point dataset containing one representative interior point (pole of
inaccessibility or centroid) per Zählsprengel across all of Austria.
Used by
[`statistik_get_zsp_einkommen()`](https://robinkohrs.github.io/dav/reference/statistik_get_zsp_einkommen.md)
to query the Statistik Austria WMS service for income data at
Zählsprengel level.

## Format

An `sf` object with one row per Zählsprengel and the following columns:

- ZGEB:

  Character. The Zählsprengel code (8-digit Kennziffer).

- geometry:

  Point geometry in EPSG:3857 (WGS 84 / Pseudo-Mercator).

## Source

Derived from Statistik Austria Zählsprengel polygon boundaries (original
CRS: EPSG:31287 MGI / Austria Lambert).

## See also

[`statistik_get_zsp_einkommen()`](https://robinkohrs.github.io/dav/reference/statistik_get_zsp_einkommen.md),
[wien_income_poi](https://robinkohrs.github.io/dav/reference/wien_income_poi.md)

## Examples

``` r
plot(at_income_poi["geometry"])

```
