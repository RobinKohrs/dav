#' Create a Responsive Stacked Bar Chart as HTML
#'
#' Generates a responsive stacked bar chart HTML string that adjusts its layout based
#' on screen size. On narrow viewports, inline bar labels are hidden and a legend is shown.
#'
#' @param data A list of lists, each with `value` (0–100), `color` (hex code), optional `name`, and optional `absolute_value`.
#' @param headline A character string for the chart title.
#' @param subheader A character string for the chart subtitle.
#' @param source_text A character string for the data source.
#' @param source_link Optional. A URL to link the source text.
#' @param legend_breakpoint_px Integer pixel width below which the legend is shown and labels are hidden.
#' @param border Optional. Logical. Whether to show a border around the chart. Defaults to TRUE.
#' @param show_legend Optional. Logical. Whether to always show the legend. Defaults to FALSE (responsive behavior).
#'
#' @return A character string containing HTML markup for the chart.
#'
#' @examples
#' data = list(
#'   list(value = 45, color = "#4CAF50", name = "Ja", absolute_value = "45 Personen"),
#'   list(value = 30, color = "#FF9800", name = "Vielleicht", absolute_value = "30 Personen"),
#'   list(value = 25, color = "#f44336", name = "Nein", absolute_value = "25 Personen")
#' )
#' html = create_responsive_stacked_bar_chart_html(
#'   data = data,
#'   headline = "Umfrageergebnis zur neuen Initiative",
#'   subheader = "Verteilung der Antworten in Prozent",
#'   source_text = "Interne Studie Q1",
#'   source_link = "https://example.com/studie",
#'   border = FALSE
#' )
#' if (requireNamespace("htmltools", quietly = TRUE)) {
#'   htmltools::html_print(htmltools::HTML(html))
#' }
#'
#' @importFrom glue glue
#' @export
html_create_stacked_bar_chart = function(
  data,
  headline,
  subheader,
  source_text,
  source_link = NULL,
  legend_breakpoint_px = 350,
  border = TRUE,
  show_legend = FALSE
) {
  if (!is.list(data) || length(data) == 0) {
    stop("`data` must be a non-empty list.")
  }
  if (length(data) > 3) {
    warning("Displaying more than 3 segments might clutter the chart.")
  }
  for (i in seq_along(data)) {
    if (!all(c("value", "color") %in% names(data[[i]]))) {
      stop(glue::glue("Segment {i} missing 'value' or 'color'."))
    }
    if (
      !is.numeric(data[[i]]$value) ||
        data[[i]]$value < 0 ||
        data[[i]]$value > 100
    ) {
      stop(glue::glue("Segment {i} 'value' invalid."))
    }
  }

  bar_segments_html = ""
  legend_items_html = ""
  total_percentage = sum(sapply(data, function(s) s$value))
  num_segments = length(data)

  for (i in seq_along(data)) {
    segment = data[[i]]
    segment_name = if (!is.null(segment$name) && nzchar(segment$name)) {
      segment$name
    } else {
      paste0("Segment ", i)
    }

    # Determine border radius based on border and segment position
    if (!border) {
      if (i == 1) {
        seg_border_radius = "5px 0 0 5px"
      } else if (i == num_segments) {
        seg_border_radius = "0 5px 5px 0"
      } else {
        seg_border_radius = "0"
      }
    } else {
      seg_border_radius = if (num_segments == 1) "5px" else "0"
    }

    hex_to_rgb = function(hex) {
      hex = gsub("#", "", hex)
      if (nchar(hex) == 3) {
        hex = paste0(
          strsplit(hex, "")[[1]],
          strsplit(hex, "")[[1]],
          collapse = ""
        )
      }
      sapply(c(1, 3, 5), function(idx) {
        strtoi(paste0("0x", substr(hex, idx, idx + 1)))
      })
    }
    rgb_color = tryCatch(hex_to_rgb(segment$color), error = function(e) {
      c(128, 128, 128)
    })
    luminance = 0.299 *
      rgb_color[1] +
      0.587 * rgb_color[2] +
      0.114 * rgb_color[3]
    text_color_inside_bar = ifelse(luminance > 128, "#333333", "#efefef")

    bar_label <- ""
    if (segment$value >= 8) {
      abs_val <- ""
      if (!is.null(segment$absolute_value)) {
        abs_val <- paste0(
          '<span style="font-size: 14px; font-weight: normal;">(',
          segment$absolute_value,
          ')</span>'
        )
      }
      bar_label <- glue::glue(
        '<span class="chart-bar-inline-label" style="font-size: 20px; font-weight: bold; color: {text_color_inside_bar}; padding-right: 12px; white-space: nowrap; text-align: right; display: flex; flex-direction: column; align-items: flex-end; gap: 0;">{segment$value}%<span style="font-size: 14px; font-weight: normal;">{abs_val}</span></span>'
      )
    }

    bar_segments_html = paste0(
      bar_segments_html,
      glue::glue(
        '<div style="width: {segment$value}%; height: 100%; background-color: {segment$color}; border-radius: {seg_border_radius}; display: flex; align-items: center; justify-content: flex-end; transition: width 0.5s ease-in-out; overflow: hidden; flex-shrink: 0;">{bar_label}</div>'
      )
    )

    legend_item_name_display = if (
      !is.null(segment$name) && nzchar(segment$name)
    ) {
      glue::glue('<span class="chart-legend-item-name">{segment$name}:</span> ')
    } else {
      ""
    }

    legend_value = if (!is.null(segment$absolute_value)) {
      glue::glue('{segment$value}% ({segment$absolute_value})')
    } else {
      glue::glue('{segment$value}%')
    }

    legend_items_html = paste0(
      legend_items_html,
      glue::glue(
        '<div class="chart-legend-item">',
        '<span class="chart-legend-color-swatch" style="background-color: {segment$color};"></span>',
        '{legend_item_name_display}',
        '<span class="chart-legend-item-value">{legend_value}</span>',
        '</div>'
      )
    )
  }

  source_content_html = source_text
  if (!is.null(source_link) && nzchar(source_link)) {
    source_content_html = glue::glue(
      '<a href="{source_link}" target="_blank" style="color: #0056b3; text-decoration: none;">{source_text}</a>'
    )
  }

  segment_descriptions = sapply(data, function(s) {
    paste0(
      s$value,
      "% ",
      ifelse(!is.null(s$name) && nzchar(s$name), s$name, "segment")
    )
  })
  chart_description = glue::glue(
    "Bar chart showing a total of {total_percentage}%. Segments: {paste(segment_descriptions, collapse='; ')}."
  )

  css_styles = glue::glue(
    ".chart-bar-inline-label {{
      white-space: nowrap;
      line-height: 1.1;
    }}
    .chart-legend {{
      display: {if (show_legend) 'block' else 'none'};
      margin-top: 10px;
      padding: 8px;
      border: 1px solid #eee;
      border-radius: 4px;
      font-size: 13px;
      line-height: 1.5;
      max-width: 100%;
      box-sizing: border-box;
    }}
    .chart-legend-item {{
      display: flex;
      align-items: center;
      margin-bottom: 4px;
      flex-wrap: wrap;
      gap: 4px;
    }}
    .chart-legend-item:last-child {{
      margin-bottom: 0;
    }}
    .chart-legend-color-swatch {{
      width: 12px;
      height: 12px;
      margin-right: 8px;
      border: 1px solid #ccc;
      display: inline-block;
      flex-shrink: 0;
    }}
    .chart-legend-item-name {{
      font-weight: bold;
      margin-right: 5px;
      overflow-wrap: break-word;
      word-break: break-word;
    }}
    .chart-legend-item-value {{
      white-space: nowrap;
    }}
    @media (max-width: {legend_breakpoint_px}px) {{
      .chart-bar-inline-label {{
        display: none !important;
      }}
      .chart-legend {{
        display: block;
      }}
    }}"
  )

  html_output = glue::glue(
    '
    <style>
      * {{
        box-sizing: border-box;
      }}
      {css_styles}
    </style>
    <div class="responsive-bar-chart-container" style="width: 100%; max-width: 615px; margin: 0 auto; font-family: STMatilda Text Variable, system-ui, serif;">
      <div style="margin: 10px 0;">
        <div style="color: #000; font-size: 1.2em; text-align: center; font-weight: 700; line-height: 1.3;"><strong>{headline}</strong></div>
        <div style="color: #888; font-size: 14px; text-align: center; line-height: 16px;">{subheader}</div>
      </div>
      <div title="{chart_description}" role="progressbar" aria-valuenow="{total_percentage}" aria-valuemin="0" aria-valuemax="100" aria-label="{chart_description}" style="width: 100%; height: 50px; background-color: transparent; {if(border) "border: 3px solid #343434;" else ""} border-radius: {if(border) "5px" else "0"}; overflow: hidden; position: relative; box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.05); display: flex; flex-wrap: nowrap;">
        {bar_segments_html}
      </div>
      <div class="chart-legend">{legend_items_html}</div>
      <p style="text-align: center; font-size: 12px; color: #777; margin-top: 8px;">Quelle: {source_content_html}</p>
    </div>
  '
  )

  return(html_output)
}
