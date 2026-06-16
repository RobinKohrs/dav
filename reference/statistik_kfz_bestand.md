# Kfz-Bestand nach Fahrzeugart oder Kraftstoffart (Zeitreihe)

Downloads all available Statistik Austria Kfz-Bestand ODS files and
returns a combined tidy tibble. Two data types are available via the
`type` argument:

## Usage

``` r
statistik_kfz_bestand(
  type = c("fahrzeugart", "kraftstoff"),
  include_vorlaeufig = TRUE,
  verbose = TRUE,
  page_url =
    "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-bestand"
)
```

## Source

<https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-bestand>

## Arguments

- type:

  Character. One of `"fahrzeugart"` (default) or `"kraftstoff"`.

- include_vorlaeufig:

  Logical. If `TRUE` (default), appends the most recent preliminary
  (vorläufig) figure (e.g. 31. März 2026).

- verbose:

  Logical. Print progress messages. Default `TRUE`.

- page_url:

  The Statistik Austria page to discover ODS links from.

## Value

A `tibble`. Columns for `type = "fahrzeugart"`:

- `stichtag`:

  `Date`.

- `vorlaeufig`:

  Logical.

- `section`:

  `"Kraftfahrzeuge"` or `"Anhänger"`.

- `bundesland`:

  State name or `"Österreich"`.

- `fahrzeugart`:

  Vehicle type.

- `anzahl`:

  Integer count.

Columns for `type = "kraftstoff"`:

- `stichtag`:

  `Date`.

- `vorlaeufig`:

  Logical.

- `bundesland`:

  State name or `"Österreich"`.

- `fahrzeugart`:

  Vehicle type. For the vorläufig file always
  `"Personenkraftwagen Klasse M1"` (PKW-only sheet).

- `kraftstoffart`:

  Fuel/energy source, e.g. `"Elektro"`, `"Diesel"`.

- `anzahl`:

  Integer count.

## Details

- `"fahrzeugart"` (default):

  Vehicle counts by Fahrzeugart and Bundesland. Annual files (tab_7)
  cover 2019–2025 with 9 broad categories. The vorläufig file provides
  more granular categories plus Anhänger by Bundesland.

- `"kraftstoff"`:

  Kfz counts by Kraftstoffart and Bundesland. Annual files are available
  for 2024–2025 (all vehicle types). The vorläufig file adds a PKW-only
  kraftstoff breakdown for the latest quarter.

**Data sources:**

- `type = "fahrzeugart"`, annual:

  `tab_7` sheet — 2019–2025. Broad Kfz categories by Bundesland.
  Anhänger are Austria-total only.

- `type = "fahrzeugart"`, vorläufig:

  `Fahrzeuge` sheet — latest quarter. Granular categories + Anhänger by
  Bundesland.

- `type = "kraftstoff"`, annual:

  `Kfz-BestandKraftfahrzeugBundeslandKraftstoffartEnergiequelle{year}.ods`
  — currently 2024–2025. All vehicle types × Kraftstoffart × Bundesland.

- `type = "kraftstoff"`, vorläufig:

  `Pkw_nach_Kraftstoff` sheet — latest quarter. PKW only × Kraftstoffart
  × Bundesland.

Files are discovered dynamically from the Statistik Austria page.

## Examples

``` r
if (FALSE) { # \dontrun{
# ---- Fahrzeugart (default) ----
statistik_kfz_bestand()
statistik_kfz_bestand(include_vorlaeufig = FALSE)

# PKW over time by Bundesland
statistik_kfz_bestand() |>
  dplyr::filter(section == "Kraftfahrzeuge",
                fahrzeugart == "Personenkraftwagen",
                bundesland != "Österreich")

# ---- Kraftstoff ----
statistik_kfz_bestand(type = "kraftstoff")

# Elektro-PKW by Bundesland
statistik_kfz_bestand(type = "kraftstoff") |>
  dplyr::filter(fahrzeugart == "Personenkraftwagen Klasse M1",
                kraftstoffart == "Elektro")
} # }
```
