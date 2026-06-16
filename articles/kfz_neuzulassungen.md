# Kfz-Daten – Österreich (Neuzulassungen & Bestand)

``` r
library(davR)
library(dplyr)
```

## Überblick

Das Paket enthält **vier Funktionen** für österreichische Kfz-Daten,
aufgeteilt in **Neuzulassungen** und **Bestand**. Alle Funktionen
entdecken URLs dynamisch — kein manuelles Link-Update nötig, wenn
Statistik Austria neue Dateien veröffentlicht.

### Bestand

| Funktion                                      | Was                                              | Zeitraum         | Quelle                |
|-----------------------------------------------|--------------------------------------------------|------------------|-----------------------|
| `statistik_kfz_bestand(type = "fahrzeugart")` | Alle Fahrzeugtypen nach Fahrzeugart × Bundesland | **2019 → heute** | Statistik Austria ODS |
| `statistik_kfz_bestand(type = "kraftstoff")`  | PKW nach Kraftstoffart × Bundesland              | **2019 → heute** | Statistik Austria ODS |

### Neuzulassungen

| Funktion                                                                                                                   | Was                                                                  | Zeitraum                   | Quelle                   |
|----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------|----------------------------|--------------------------|
| [`statistik_pkw_kraftstoff_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_neuzulassungen_zeitreihe.md) | PKW nach Kraftstoffart × Bundesland                                  | **2006-01 → heute**        | Bundled Excel + live ODS |
| [`statistik_kfz_neuzulassungen()`](https://robinkohrs.github.io/dav/reference/statistik_kfz_neuzulassungen.md)             | Alle Fahrzeugtypen nach Kraftstoff × Bundesland **oder** Marke × Typ | Aktuelles Jahr + 2024/2025 | Statistik Austria ODS    |
| [`statistik_pkw_marken_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_pkw_marken_zeitreihe.md)         | PKW nach Marke                                                       | **2000-01 → heute**        | STATcube OGD API         |

### Was kann ich damit beantworten?

| Frage                                                          | Funktion                                                                                                                   |
|----------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| Wie viele E-Autos sind in Wien zugelassen?                     | `statistik_kfz_bestand(type = "kraftstoff")`                                                                               |
| Wie hat sich der LKW-Bestand entwickelt?                       | [`statistik_kfz_bestand()`](https://robinkohrs.github.io/dav/reference/statistik_kfz_bestand.md)                           |
| Wie entwickelt sich der Anteil von E-Autos bei Neuzulassungen? | [`statistik_pkw_kraftstoff_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_neuzulassungen_zeitreihe.md) |
| Welche Marke hat heuer die meisten PKW neu zugelassen?         | [`statistik_pkw_marken_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_pkw_marken_zeitreihe.md)         |
| Wie viele Teslas wurden seit 2020 neu zugelassen?              | [`statistik_pkw_marken_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_pkw_marken_zeitreihe.md)         |
| Neue Fahrzeuge nach Kraftstoff + Fahrzeugtyp im Detail?        | [`statistik_kfz_neuzulassungen()`](https://robinkohrs.github.io/dav/reference/statistik_kfz_neuzulassungen.md)             |

------------------------------------------------------------------------

## 1 · `statistik_kfz_bestand()` — Kfz-Bestand (alle Fahrzeugtypen)

Gibt den **Kfz-Bestand** (alle angemeldeten Fahrzeuge zum Stichtag)
zurück. Der `type`-Parameter steuert, welche Dimension zurückgegeben
wird.

### `type = "fahrzeugart"` (Standard) — Fahrzeugart × Bundesland

**Datenquellen:** - **Jahreswerte (31. Dezember):** 2019–2025. Enthält
alle Kraftfahrzeuge nach Bundesland sowie Anhänger-Gesamtzahl für
Österreich. - **Vorläufige Daten (aktuellstes Quartal):** z. B. 31. März
2026. Enthält zusätzlich Anhänger aufgeschlüsselt nach Bundesland.

**Spalten:** `stichtag`, `vorlaeufig`, `section` (`"Kraftfahrzeuge"` /
`"Anhänger"`), `bundesland`, `fahrzeugart`, `anzahl`

``` r
# Alle Jahreswerte 2019–2025 + aktuellster vorläufiger Wert
statistik_kfz_bestand()
```

``` r
# Nur Jahreswerte, keine vorläufigen Daten
statistik_kfz_bestand(include_vorlaeufig = FALSE)
```

``` r
# PKW-Bestand nach Bundesland über die Jahre
statistik_kfz_bestand() |>
  filter(section == "Kraftfahrzeuge",
         fahrzeugart == "Personenkraftwagen",
         bundesland != "Österreich") |>
  select(stichtag, bundesland, anzahl) |>
  arrange(bundesland, stichtag)
```

``` r
# Anhänger-Bestand für Österreich
statistik_kfz_bestand() |>
  filter(section == "Anhänger", bundesland == "Österreich") |>
  select(stichtag, fahrzeugart, anzahl)
```

### `type = "kraftstoff"` — Kraftstoffart × Bundesland

**Datenquellen:** - **tab_3 aus den Jahres-ODS (2019–2023):** PKW-only ×
Kraftstoffart × Bundesland, direkt aus dem Haupt-ODS jedes Jahres. -
**Separate Kraftstoffart-Dateien (2024+):**
`Kfz-BestandKraftfahrzeugBundeslandKraftstoffartEnergiequelle{year}.ods`
— alle Fahrzeugtypen × Kraftstoffart × Bundesland (reichhaltigerer
Datensatz). - **Vorläufige Daten:** `Pkw_nach_Kraftstoff`-Sheet —
PKW-only × Kraftstoffart × Bundesland.

**Spalten:** `stichtag`, `vorlaeufig`, `bundesland`, `fahrzeugart`,
`kraftstoffart`, `anzahl`

> **Hinweis:** Für 2019–2023 ist `fahrzeugart` immer
> `"Personenkraftwagen"` (PKW-only). Ab 2024 enthält der Datensatz auch
> alle anderen Fahrzeugtypen (Lkw, Motorräder usw.). Der vorläufige
> Datensatz hat `fahrzeugart = "Personenkraftwagen Klasse M1"`.

``` r
# PKW/Kfz nach Kraftstoffart — 2024-12-31, 2025-12-31, vorläufig 2026
statistik_kfz_bestand(type = "kraftstoff")
```

``` r
# Elektro-PKW nach Bundesland, letzter verfügbarer Stichtag
statistik_kfz_bestand(type = "kraftstoff") |>
  filter(fahrzeugart == "Personenkraftwagen Klasse M1",
         kraftstoffart == "Elektro") |>
  arrange(desc(stichtag), desc(anzahl))
```

``` r
# Alle Kraftstoffarten für PKW in Österreich gesamt über die Zeit
statistik_kfz_bestand(type = "kraftstoff") |>
  filter(fahrzeugart == "Personenkraftwagen Klasse M1",
         bundesland == "Österreich") |>
  select(stichtag, kraftstoffart, anzahl) |>
  arrange(stichtag, kraftstoffart)
```

### Verfügbare Kraftstoffarten (in Kraftstoff-Daten)

| Kraftstoffart                 |
|-------------------------------|
| Benzin inkl. Flex-Fuel        |
| Diesel                        |
| Elektro                       |
| Flüssiggas                    |
| Erdgas                        |
| Benzin/Flüssiggas (bivalent)  |
| Benzin/Erdgas (bivalent)      |
| Benzin/Elektro (hybrid)       |
| Diesel/Elektro (hybrid)       |
| Wasserstoff (Brennstoffzelle) |

### Verfügbare Fahrzeugarten (in Fahrzeugart-Daten)

**Jahreswerte (alle Bundesländer):** Personenkraftwagen, Krafträder,
Motorfahrräder, Lkw Klasse N1, Lkw Klasse N2+N3, Sattelzugfahrzeuge,
Zugmaschinen, Sonstige Kfz.

**Vorläufige Daten (granularer):** Personenkraftwagen Kl. M1, Motorräder
Kl. L3e, Lkw N1/N2/N3, Omnibusse, Wohnmobile, Zugmaschinen, Anhänger Kl.
O und R, Wohnanhänger, u. v. m.

------------------------------------------------------------------------

## 2 · `statistik_pkw_kraftstoff_zeitreihe()` — Lange Zeitreihe nach Kraftstoffart

Der wichtigste Datensatz für Trendanalysen bei Neuzulassungen. Gibt
**monatliche PKW-Neuzulassungen** nach Bundesland und Kraftstoffart von
**Jänner 2006** bis zum aktuellsten verfügbaren Monat zurück.

- **2006–2025**: kommt aus dem gebündelten Dataset
  `at_pkw_kraftstoff_hist` (offline, sofort verfügbar)
- **Aktuelles Jahr**: wird live von der Statistik-Austria-Website
  geladen

**Spalten:** `bundesland`, `kraftstoffart`, `year`, `month`, `date`,
`anzahl`

``` r
# Elektro-Zeitreihe für ganz Österreich
statistik_pkw_kraftstoff_zeitreihe(kraftstoffart = "Elektro")
```

``` r
# Wien: Elektro vs. Diesel seit 2020
statistik_pkw_kraftstoff_zeitreihe(
  date_from     = "2020-01",
  bundesland    = c("Wien", "Österreich"),
  kraftstoffart = c("Elektro", "Diesel")
)
```

``` r
# Nur historische Daten (kein Netzwerkaufruf)
statistik_pkw_kraftstoff_zeitreihe(include_current_year = FALSE)
```

------------------------------------------------------------------------

## 3 · `statistik_kfz_neuzulassungen()` — Detailliertere Jahres-Auswertung

Gibt mehr Detail für das aktuelle Jahr (oder Jahressummen 2024/2025):
Aufschlüsselung nach Fahrzeugtyp (PKW, Motorrad, LKW …), Bundesland und
Kraftstoffart — **oder** nach Marke × Fahrzeugtyp.

> **Hinweis:** Für eine lange Zeitreihe lieber
> [`statistik_pkw_kraftstoff_zeitreihe()`](https://robinkohrs.github.io/dav/reference/statistik_neuzulassungen_zeitreihe.md)
> verwenden.

### `type = "kraftstoff"` — Kraftstoff × Fahrzeugtyp × Bundesland

**Spalten:** `monat`, `bundesland`, `fahrzeugtyp`, `kraftstoffart`,
`anzahl`

``` r
# Alle Monate des aktuellen Jahres
statistik_kfz_neuzulassungen("kraftstoff")
```

``` r
# Nur Jänner, Elektro-PKW je Bundesland
df <- statistik_kfz_neuzulassungen("kraftstoff", months = "Jänner")

df |>
  filter(fahrzeugtyp == "Personenkraftwagen Klasse M1",
         kraftstoffart == "Elektro") |>
  select(bundesland, anzahl) |>
  arrange(desc(anzahl))
```

``` r
# Jahressumme 2025
statistik_kfz_neuzulassungen("kraftstoff", year = 2025)
```

### `type = "marken"` — Marke × Fahrzeugtyp (nur aktuelles Jahr)

**Spalten:** `monat`, `marke`, `fahrzeugtyp`, `anzahl`

``` r
dm <- statistik_kfz_neuzulassungen("marken")

# Top 10 PKW-Marken im Jänner
dm |>
  filter(monat == "Jänner",
         grepl("Personenkraftwagen", fahrzeugtyp),
         marke != "Kraftfahrzeuge insgesamt") |>
  slice_max(anzahl, n = 10) |>
  select(marke, anzahl)
```

------------------------------------------------------------------------

## 4 · `statistik_pkw_marken_zeitreihe()` — PKW nach Marke seit 2000

Nutzt die **OGD REST API** (`data.statistik.gv.at`) und gibt monatliche
PKW-Neuzulassungen nach Marke von **Jänner 2000** bis heute zurück.

**Spalten:** `monat`, `date`, `brand`, `producing_country`,
`is_ev_only`, `marke`, `anzahl`

> **Wichtig:** Manche Marken erscheinen mehrfach nach Herstellungsland.
> `"AUDI (D)"` und `"AUDI (H)"` sind getrennte Zeilen — für eine
> Gesamt-Zahl nach `brand` gruppieren, nicht nach `marke`.

``` r
# Alle Marken im aktuellen Jahr
statistik_pkw_marken_zeitreihe(
  date_from = paste0(format(Sys.Date(), "%Y"), "-01")
)
```

``` r
# Ausgewählte Marken seit 2015
statistik_pkw_marken_zeitreihe(
  date_from = "2015-01",
  marken    = c("VW", "SKODA", "BMW", "MERCEDES", "TOYOTA", "TESLA")
)
```

``` r
# Nur reine E-Auto-Marken seit 2020
statistik_pkw_marken_zeitreihe(date_from = "2020-01") |>
  filter(is_ev_only) |>
  summarise(anzahl = sum(anzahl, na.rm = TRUE), .by = c(date, brand)) |>
  arrange(date, desc(anzahl))
```

``` r
# Top 15 Marken im letzten verfügbaren Monat
statistik_pkw_marken_zeitreihe() |>
  filter(date == max(date)) |>
  summarise(anzahl = sum(anzahl, na.rm = TRUE), .by = brand) |>
  slice_max(anzahl, n = 15)
```

------------------------------------------------------------------------

## Was kann ich (noch) nicht?

| Frage                                                                  | Warum nicht                                                                  |
|------------------------------------------------------------------------|------------------------------------------------------------------------------|
| PKW-Neuzulassungen nach **Marke × Kraftstoff**                         | Statistik Austria veröffentlicht diese Kombination nicht als Open Data       |
| Bestand nach **anderen Fahrzeugtypen × Kraftstoff** für Jahre vor 2024 | Separate Kraftstoffart-Dateien erst ab 2024. Für 2019–2023 nur PKW via tab_3 |
| Anhänger-Bestand nach **Bundesland** für Jahreswerte                   | In den jährlichen ODS-Dateien nicht vorhanden — nur Österreich gesamt        |

------------------------------------------------------------------------

## Datenquellen

| Quelle                                        | URL                                                                                       |
|-----------------------------------------------|-------------------------------------------------------------------------------------------|
| Statistik Austria – Kfz-Neuzulassungen        | <https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen> |
| Statistik Austria – Kfz-Bestand               | <https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-bestand>        |
| OGD API – PKW-Neuzulassungen nach Marken      | <https://data.statistik.gv.at/web/meta.jsp?dataset=OGD_fkfzul0759_OD_PkwNZL_1>            |
| Bundled historisches Excel (Sonderauswertung) | `system.file("extdata", "at_pkw_kraftstoff_hist_2006_2025.xlsx", package = "davR")`       |

Lizenz: CC BY 4.0 – Statistik Austria.
