# Get Zählsprengel Income Data from Statistik Austria

Downloads income statistics per Zählsprengel from the Statistik Austria
WMS service. Uses poles of inaccessibility or centroids to query each
district precisely with a single request per Zählsprengel.

## Usage

``` r
statistik_get_zsp_einkommen(
  year,
  income_var = c("pers_geseink", "pers_netto", "hh_geseink", "hh_netto"),
  poi = at_income_poi,
  sleep_ms = 10,
  cache_dir = "/Volumes/rr/geodata/österreich/einkommen_zählsprengel",
  verbose = TRUE
)
```

## Arguments

- year:

  Integer. The year for which to download income data (2012–2022).

- income_var:

  Character. Which income variable to download. One of `"pers_geseink"`
  (default), `"pers_netto"`, `"hh_geseink"`, `"hh_netto"`.

- poi:

  An sf object with point geometry (poles of inaccessibility or
  centroids) and a `ZGEB` column identifying each Zählsprengel. Must be
  in EPSG:3857 or any CRS (will be reprojected automatically). Defaults
  to the bundled
  [wien_income_poi](https://robinkohrs.github.io/dav/reference/wien_income_poi.md)
  dataset covering all Vienna Zählsprengel. For Austria-wide data use
  the `at_zsp_poi` dataset.

- sleep_ms:

  Integer. Delay in milliseconds between requests (default: 100).

- cache_dir:

  Character. Path to a directory used to store and resume intermediate
  download state. A CSV file named
  `zsp_einkommen_<income_var>_<year>.csv` is written after each request.
  On subsequent calls with the same arguments, already-queried
  Zählsprengel are skipped automatically. Defaults to
  `"/Volumes/rr/geodata/österreich/einkommen_zählsprengel"`. Set to NULL
  to disable caching.

- verbose:

  Logical. If TRUE (default), prints progress messages.

## Value

A data frame with columns `ID`, `g_id`, and the income variable name
(e.g. `geseink_mean`), deduplicated by `g_id`. Returns NULL if no
features were collected.

## Details

Four income variables are available:

- `"pers_geseink"`:

  Mean total income incl. transfer payments per person.

- `"pers_netto"`:

  Mean net income per person.

- `"hh_geseink"`:

  Mean total income incl. transfer payments per household.

- `"hh_netto"`:

  Mean net income per household.

## Examples

``` r
if (FALSE) { # \dontrun{
# Gesamteinkommen per person for 2022 (Vienna, default poi)
statistik_get_zsp_einkommen(2022)

# Nettoeinkommen per person
statistik_get_zsp_einkommen(2022, income_var = "pers_netto")

# Household total income, resumable download cached to disk
statistik_get_zsp_einkommen(2022, income_var = "hh_geseink",
  cache_dir = "data/cache")

# Austria-wide using at_zsp_poi
statistik_get_zsp_einkommen(2022, poi = at_zsp_poi)
} # }
```
