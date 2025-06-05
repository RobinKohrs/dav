README.txt
===========

Titel: Nächtliche Durchschnittstemperaturen (18–6 Uhr MESZ) – GeoSphere Austria Stationsdaten
Autor: Robin Kohrs
Kontakt: robin.kohrs@gmx.de
Quelle: https://data.hub.geosphere.at/dataset/klima-v2-1h
Lizenz: CC BY 4.0
DOI: https://doi.org/10.60669/9bdm-yq93

Beschreibung
------------
Die Daten zeigen durchschnittliche Nachttemperaturen zwischen 18:00 und 06:00 Uhr (MESZ)
für die Sommermonate Juni, Juli und August – getrennt nach Jahr und Station.
Es handelt sich um Lufttemperaturen in **2 m Höhe** über Boden.
Die Analyse wurde mit **R** durchgeführt. Grundlage sind stündliche Temperaturwerte
aus dem GeoSphere Austria-Datensatz "Messstationen Stundendaten v2".

Datenstruktur (CSV)
-------------------
Spaltenübersicht:
- `station_name`: Name der Wetterstation
- `station_id`: Interne Stations-ID
- `year`: Jahr der Messung
- `share_no_data`: Anteil fehlender Stundenwerte in der Nacht (0 = vollständig, 1 = keine Daten)
- `Jun`, `Jul`, `Aug`: Ø Nachttemperatur (°C) im jeweiligen Monat
- `Jun_5yr_avg`, `Jul_5yr_avg`, `Aug_5yr_avg`: Gleitender 5-Jahres-Mittelwert (falls vorhanden)

Beispiel:
station_name,station_id,year,share_no_data,Jun,Jul,Aug,Jun_5yr_avg,Jul_5yr_avg,Aug_5yr_avg
Zwerndorf,4305,1997,0,15.02,15.57,16.16,NA,NA,NA

Nutzungshinweise
----------------
Die Dateien sind als CSV (Komma-getrennt, Punkt als Dezimaltrennzeichen) formatiert
und kompatibel mit Tools wie **Datawrapper**, **Flourish**, **Excel** oder **Google Sheets**.
In Datawrapper: Leere Felder oder "NA" als "missing" interpretieren.
