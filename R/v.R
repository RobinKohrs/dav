#' Quickly View a Data Frame
#'
#' A convenience wrapper around [DT::datatable()] for fast, nicely formatted
#' interactive table previews. Numeric columns are automatically rounded and
#' alignment issues are handled via column adjustment.
#'
#' @param df A data frame (or tibble) to display.
#' @param title Character. An optional title for the table.
#' @param digits Integer. Number of decimal places for numeric columns. Defaults to 1.
#' @param n_rows The numbers of rows shown by default.
#' @param font_size Character. CSS font size for body cells. Defaults to `"10px"`.
#' @param header_font_size Character. CSS font size for column headers. Defaults to `"11px"`.
#'
#' @return A [DT::datatable] widget.
#' @export
v <- function(df, title = NULL, digits = 1, n_rows = 25, font_size = "10px", header_font_size = "11px") {

  if (!requireNamespace("DT", quietly = TRUE)) {
    stop("Package 'DT' is required. Install it with install.packages('DT').")
  }
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    stop("Package 'htmltools' is required. Install it with install.packages('htmltools').")
  }

  num_cols <- names(df)[vapply(df, is.numeric, logical(1))]

  widget <- DT::datatable(
    df,
    caption = title,
    rownames = FALSE,
    options = list(
      scrollX = TRUE,
      pageLength = n_rows,
      autoWidth = FALSE, # Set to FALSE to prevent header/body mismatch
      columnDefs = list(list(className = "dt-center", targets = "_all")),
      # Force column alignment adjustment on load
      initComplete = DT::JS(
        "function(settings, json) {",
        paste0("$(this.api().table().header()).css({'font-size': '", header_font_size, "'});"),
        "setTimeout(function() { settings.oInstance.api().columns.adjust(); }, 10);",
        "}"
      )
    ),
    class = "compact stripe hover border-column"
  )

  # Format numeric columns
  if (length(num_cols) > 0) {
    widget <- DT::formatRound(widget, columns = num_cols, digits = digits)
  }

  # Apply body font size
  widget <- DT::formatStyle(
    widget,
    columns = names(df),
    fontSize = font_size
  )

  # Inject CSS for scrollbars and alignment forcing
  header_css <- htmltools::tags$style(sprintf(
    "table.dataTable { width: 100%% !important; margin: 0 auto !important; }
     .dataTables_wrapper thead th { font-size: %s !important; white-space: nowrap; }
     .dataTables_wrapper .dataTables_scrollBody {
       overflow: auto !important;
     }
     .dataTables_wrapper .dataTables_scrollBody::-webkit-scrollbar {
       width: 8px;
       height: 8px;
     }
     .dataTables_wrapper .dataTables_scrollBody::-webkit-scrollbar-thumb {
       border-radius: 4px;
       background-color: rgba(0, 0, 0, 0.3);
     }",
    header_font_size
  ))

  widget <- htmlwidgets::prependContent(widget, header_css)

  return(widget)
}
