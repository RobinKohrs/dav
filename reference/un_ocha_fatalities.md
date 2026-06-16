# Fetch casualty data from UN OCHA's Protection of Civilians database

Queries fatality and injury counts broken down by region for
Palestinians and Israelis from the Power BI dashboards embedded on
<https://www.ochaopt.org/data/casualties>. Data covers occupation- and
conflict-related incidents in the occupied Palestinian territory (OPT)
and Israel since 2008.

## Usage

``` r
un_ocha_fatalities(
  type = c("all", "pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries"),
  group_by = NULL,
  region = NULL,
  filters = NULL,
  area = NULL
)
```

## Arguments

- type:

  Character. Which dataset to retrieve. One of:

  `"all"` (default)

  :   Returns a named list containing all four tibbles. Failed
      sub-queries return `NULL` with a warning.

  `"pal_fatalities"`

  :   Palestinian fatalities by governorate.

  `"isr_fatalities"`

  :   Israeli fatalities by area.

  `"pal_injuries"`

  :   Palestinian injuries by governorate.

  `"isr_injuries"`

  :   Israeli injuries by area.

- region:

  Optional character vector of region/governorate names to **include**.
  Applied as an IN-filter on the dataset's region column (e.g.
  `"Govornorate (groups)"` for Palestinian datasets). Use
  [`un_ocha_fetch_filter_values`](https://robinkohrs.github.io/dav/reference/un_ocha_fetch_filter_values.md)
  to discover the exact strings accepted by the data model. Ignored for
  datasets that have no region column (`isr_fatalities`). Cannot be used
  with `type = "all"`.

- area:

  Optional character vector for quick geographic subsetting of
  Palestinian datasets. One or more of `"west_bank"`, `"israel"`,
  `"gaza"`. Expands to the corresponding set of OCHA governorate names
  and is applied as an IN-filter on `"Govornorate (groups)"`. Can be
  combined with `region` or `filters`; the resulting filter is the union
  of all specified governorates. Silently ignored for `isr_fatalities`
  and `isr_injuries` (which use a different region dimension). Cannot be
  used with `type = "all"`.

## Value

A tibble (for a single `type`) or a named list of tibbles (for
`type = "all"`). Each tibble has two columns: the region name and the
aggregate count, ordered descending by count.

## Details

**Data source:** The underlying data comes from OCHA's Protection of
Civilians (POC) database. Incidents are independently verified by OCHA
field staff and require at least two independent, reliable sources
before entry.

**Coverage note:** Casualties from the Gaza hostilities that began on 7
October 2023 are *not* included here; those figures appear in OCHA's
Humanitarian Situation Updates.

**Implementation notes:** Data is retrieved by replicating POST requests
to the Power BI backend API
(`wabi-north-europe-j-primary-api.analysis.windows.net`). Each of the
four dashboards requires a distinct `X-PowerBI-ResourceKey` header.

**Dataset-specific notes:**

- **pal_fatalities** — grouped by governorate (note: `"Govornorate"` is
  the actual spelling in OCHA's data model, not a typo here). A NOT IN
  null guard on `Hostilities` is always applied; omitting it returns
  different totals.

- **isr_fatalities** — uses `CountNonNull` aggregation on `Fatalities`.
  Group by `"Region"` (Area) returns totals for Gaza Strip, West Bank,
  Israel. Also supports grouping by `"Date"`, `"SA (groups)"`,
  `"Govornorate (groups)"`, and filtering by
  `"victim_affiliation (groups) 2"` (e.g., `"Israeli Civilians"`,
  `"Security forces"`, `"Civilian-settler"`).

- **pal_injuries** — a `Poc_Period IN ('yes', 'Yes')` filter is always
  applied; omitting it returns a different total. The date column in
  this view is `"Date:"` (with a trailing colon — real data model
  quirk). Sanity-check total: 165,765.

- **isr_injuries** — grouped by `Community`. Uses Window-based
  pagination (1,000 rows/page with RestartToken). Uses `CountNonNull`.
  The measure column name contains a trailing space (`"Injuries "`) —
  this is the real data model name. Sanity-check total: 6,697.

## See also

[`un_ocha_fetch_filter_values`](https://robinkohrs.github.io/dav/reference/un_ocha_fetch_filter_values.md)
to discover the exact string values available for any filterable column.

## Examples

``` r
if (FALSE) { # \dontrun{
# Palestinian fatalities by governorate (default)
pal_fat <- un_ocha_fatalities("pal_fatalities")

# Palestinian fatalities over time
pal_fat_ts <- un_ocha_fatalities("pal_fatalities", group_by = "Date")

# By weapon type
pal_fat_weapon <- un_ocha_fatalities("pal_fatalities", group_by = "Weapon_name (groups)")

# All four datasets at once
all_data <- un_ocha_fatalities("all")
} # }
```
