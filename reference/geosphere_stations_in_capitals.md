# Weather Stations in Austrian Capitals

A dataset containing information about selected weather stations located
in or representative of the nine Austrian federal state capitals. This
data is a filtered subset from the
[`geosphere_get_stations()`](https://robinkohrs.github.io/dav/reference/geosphere_get_stations.md)
function.

## Usage

``` r
geosphere_stations_in_capitals
```

## Format

A data frame (or `sf` object if geometry was kept) with X rows and Y
variables:

- type:

  Type of station (e.g., COMBINED, INDIVIDUAL)

- id:

  Unique station identifier

- group_id:

  Group identifier, if applicable

- name:

  Name of the station

- state:

  Austrian federal state (Bundesland)

- lat:

  Latitude of the station

- lon:

  Longitude of the station

- altitude:

  Altitude of the station in meters

- valid_from:

  Character string, start date of data validity (ISO 8601)

- valid_to:

  Character string, end date of data validity (ISO 8601)

- has_sunshine:

  Logical, whether the station measures sunshine duration

- has_global_radiation:

  Logical, whether the station measures global radiation

- is_active:

  Logical, whether the station is currently active

- geometry:

  If it's an sf object, the POINT geometry

- ...:

  any other columns present

## Source

Derived from
[`geosphere_get_stations()`](https://robinkohrs.github.io/dav/reference/geosphere_get_stations.md),
filtered by specific station IDs representing Austrian capitals. Data
originally from GeoSphere Austria. The selection of IDs can be found in
`data-raw/geosphere_stations.R`.

## Examples

``` r
# \donttest{
  # Ensure the package is loaded if you're running this outside the package environment
  # library(yourpackagename)

  data(geosphere_stations_in_capitals)
  head(geosphere_stations_in_capitals)
#> Simple feature collection with 6 features and 13 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 9.74611 ymin: 46.64833 xmax: 16.35639 ymax: 48.29639
#> Geodetic CRS:  WGS 84
#>       type  id group_id                            name            state
#> 1 COMBINED  15       NA                         Bregenz       Vorarlberg
#> 2 COMBINED  30       NA Graz Universität/Heinrichstraße       Steiermark
#> 3 COMBINED  48       NA            Klagenfurt Flughafen          Kärnten
#> 4 COMBINED  56       NA                      Linz Stadt   Oberösterreich
#> 5 COMBINED  93       NA              St.Pölten Landhaus Niederösterreich
#> 6 COMBINED 105       NA                 Wien Hohe Warte             Wien
#>        lat      lon altitude                valid_from
#> 1 47.49917  9.74611    424.0 1936-01-01T00:00:00+00:00
#> 2 47.08000 15.44806    366.0 1894-01-01T00:00:00+00:00
#> 3 46.64833 14.31833    450.0 1952-07-01T00:00:00+00:00
#> 4 48.29639 14.28528    262.0 1895-07-01T00:00:00+00:00
#> 5 48.19972 15.63111    273.6 1947-01-01T00:00:00+00:00
#> 6 48.24861 16.35639    198.0 1775-01-01T00:00:00+00:00
#>                    valid_to has_sunshine has_global_radiation is_active
#> 1 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#> 2 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#> 3 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#> 4 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#> 5 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#> 6 2100-12-31T00:00:00+00:00         TRUE                 TRUE      TRUE
#>                    geometry
#> 1  POINT (9.74611 47.49917)
#> 2    POINT (15.44806 47.08)
#> 3 POINT (14.31833 46.64833)
#> 4 POINT (14.28528 48.29639)
#> 5 POINT (15.63111 48.19972)
#> 6 POINT (16.35639 48.24861)

  if (requireNamespace("dplyr", quietly = TRUE)) {
    dplyr::glimpse(geosphere_stations_in_capitals)
  }
#> Rows: 10
#> Columns: 14
#> $ type                 <chr> "COMBINED", "COMBINED", "COMBINED", "COMBINED", "…
#> $ id                   <int> 15, 30, 48, 56, 93, 105, 131, 5925, 7704, 11803
#> $ group_id             <int> NA, NA, NA, NA, NA, NA, NA, NA, 22, 39
#> $ name                 <chr> "Bregenz", "Graz Universität/Heinrichstraße", "Kl…
#> $ state                <chr> "Vorarlberg", "Steiermark", "Kärnten", "Oberöster…
#> $ lat                  <dbl> 47.49917, 47.08000, 46.64833, 48.29639, 48.19972,…
#> $ lon                  <dbl> 9.74611, 15.44806, 14.31833, 14.28528, 15.63111, …
#> $ altitude             <dbl> 424.0, 366.0, 450.0, 262.0, 273.6, 198.0, 430.0, …
#> $ valid_from           <chr> "1936-01-01T00:00:00+00:00", "1894-01-01T00:00:00…
#> $ valid_to             <chr> "2100-12-31T00:00:00+00:00", "2100-12-31T00:00:00…
#> $ has_sunshine         <lgl> TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, T…
#> $ has_global_radiation <lgl> TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, T…
#> $ is_active            <lgl> TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, T…
#> $ geometry             <POINT [°]> POINT (9.74611 47.49917), POINT (15.44806 47.08),…
# }
```
