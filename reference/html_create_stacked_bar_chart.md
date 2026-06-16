# Create a Responsive Stacked Bar Chart as HTML

Generates a responsive stacked bar chart HTML string that adjusts its
layout based on screen size. On narrow viewports, inline bar labels are
hidden and a legend is shown.

## Usage

``` r
html_create_stacked_bar_chart(
  data,
  headline,
  subheader,
  source_text,
  source_link = NULL,
  break_point_legend = 350,
  header_margin = "10px 0",
  headline_margin = "0",
  font_size_dt = "18px",
  font_size_mb = "12px",
  padding_bar_labels = "12px",
  bg_gradient =
    "linear-gradient(to bottom, rgba(255,255,255,0.2), rgba(255,255,255,0.0) 80%)",
  border_radius = "3px",
  border = TRUE,
  show_legend = FALSE
)
```

## Arguments

- data:

  A list of lists, each with `value` (0–100), `color` (hex code),
  optional `name`, and optional `absolute_value`.

- headline:

  A character string for the chart title.

- subheader:

  A character string for the chart subtitle.

- source_text:

  A character string for the data source.

- source_link:

  Optional. A URL to link the source text.

- break_point_legend:

  Integer pixel width below which the legend is shown and labels are
  hidden.

- header_margin:

  Optional. Character string. CSS margin for the header container
  (headline + subheader). Defaults to "10px 0".

- headline_margin:

  Optional. Character string. CSS margin for the headline element.
  Defaults to "0".

- font_size_dt:

  Optional. Font size for labels on desktop. Defaults to "18px".

- font_size_mb:

  Optional. Font size for labels on mobile (\< 650px). Defaults to
  "12px".

- padding_bar_labels:

  Optional. Padding for bar labels. Defaults to "12px".

- bg_gradient:

  Optional. CSS background gradient string. Defaults to a white fade.

- border_radius:

  Optional. CSS border radius for the container. Defaults to "3px".

- border:

  Optional. Logical. Whether to show a border around the chart. Defaults
  to TRUE.

- show_legend:

  Optional. Logical. Whether to always show the legend. Defaults to
  FALSE (responsive behavior).

## Value

A character string containing HTML markup for the chart.

## Examples

``` r
data = list(
  list(value = 45, color = "#4CAF50", name = "Ja", absolute_value = "45 Personen"),
  list(value = 30, color = "#FF9800", name = "Vielleicht", absolute_value = "30 Personen"),
  list(value = 25, color = "#f44336", name = "Nein", absolute_value = "25 Personen")
)
html = create_responsive_stacked_bar_chart_html(
  data = data,
  headline = "Umfrageergebnis zur neuen Initiative",
  subheader = "Verteilung der Antworten in Prozent",
  source_text = "Interne Studie Q1",
  source_link = "https://example.com/studie",
  border = FALSE
)
#> Error in create_responsive_stacked_bar_chart_html(data = data, headline = "Umfrageergebnis zur neuen Initiative",     subheader = "Verteilung der Antworten in Prozent", source_text = "Interne Studie Q1",     source_link = "https://example.com/studie", border = FALSE): could not find function "create_responsive_stacked_bar_chart_html"
if (requireNamespace("htmltools", quietly = TRUE)) {
  htmltools::html_print(htmltools::HTML(html))
}
#> Error: object 'html' not found
```
