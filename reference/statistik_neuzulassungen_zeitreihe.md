# Kfz-Neuzulassungen Zeitreihe nach Bundesland und Kraftstoffart (2006 – heute)

Liefert monatliche Neuzulassungszahlen aus Statistik Austria. Kombiniert
gebündelte Historik (2006–2025) mit den jeweils aktuellen Daten des
laufenden Jahres, die dynamisch von der Statistik-Austria-Website
geladen werden.

## Usage

``` r
statistik_neuzulassungen_zeitreihe(
  fahrzeugtyp = "pkw",
  kraftstoffart = NULL,
  bundesland = NULL,
  date_from = NULL,
  date_to = NULL,
  include_current_year = TRUE,
  verbose = TRUE,
  page_url =
    "https://www.statistik.at/statistiken/tourismus-und-verkehr/fahrzeuge/kfz-neuzulassungen"
)

statistik_pkw_neuzulassungen_zeitreihe(...)

statistik_pkw_kraftstoff_zeitreihe(...)
```

## Arguments

- fahrzeugtyp:

  `"pkw"` (Standard) oder `NULL`.

  - `"pkw"` — nur Personenkraftwagen Klasse M1; Zeitreihe 2006 bis
    heute.

  - `NULL` — alle Kfz-Typen; nur laufendes Jahr verfügbar, da die
    Historik ausschließlich PKW-Daten enthält.

- kraftstoffart:

  Character-Vektor der gewünschten Kraftstoffarten, z.B.
  `c("Elektro", "Diesel")`. `NULL` (Standard) liefert alle
  Kraftstoffarten.

- bundesland:

  Character-Vektor der gewünschten Bundesländer, z.B.
  `c("Wien", "Tirol")`. `"Österreich"` ist die nationale Summe. `NULL`
  (Standard) liefert alle Bundesländer.

- date_from:

  `"YYYY-MM"` oder `Date`. Nur Zeilen ab diesem Monat. Standard: `NULL`
  (alle verfügbaren Daten).

- date_to:

  `"YYYY-MM"` oder `Date`. Nur Zeilen bis zu diesem Monat. Standard:
  `NULL`.

- include_current_year:

  Logical. `TRUE` (Standard) lädt das aktuelle Jahr von Statistik
  Austria nach. `FALSE` gibt nur die gebündelte Historik zurück.

- verbose:

  Logical. Fortschrittsmeldungen ausgeben.

- page_url:

  URL der Statistik-Austria-Seite zur ODS-Erkennung.

## Value

Ein `tibble` mit den Spalten:

- `bundesland`:

  Bundesland oder `"Österreich"` (nationale Summe).

- `kraftstoffart`:

  Kraftstoff- bzw. Antriebsart.

- `year`:

  Jahr (Integer).

- `month`:

  Monat (Integer, 1–12).

- `date`:

  `Date`: erster Tag des Monats.

- `anzahl`:

  Anzahl Neuzulassungen (Integer).

## Examples

``` r
if (FALSE) { # \dontrun{
# PKW-Zeitreihe 2006 bis heute (Standard)
statistik_neuzulassungen_zeitreihe()

# Nur Elektro-PKW, Wien + national
statistik_neuzulassungen_zeitreihe(
  kraftstoffart = "Elektro",
  bundesland    = c("Wien", "Österreich")
)

# Alle Kfz-Typen — nur aktuelles Jahr verfügbar
statistik_neuzulassungen_zeitreihe(fahrzeugtyp = NULL)

# Seit 2020
statistik_neuzulassungen_zeitreihe(date_from = "2020-01")
} # }
```
