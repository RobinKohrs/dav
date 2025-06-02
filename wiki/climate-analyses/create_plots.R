# Example of how to use the function (as provided in your script):
# Ensure you have the necessary libraries loaded:
library(tidyverse)
library(glue)
library(ggtext)
library(cli)
library(scales)
library(davR)

# Helper function to convert points to pixels for ggtext (internal)
.pt_to_px <- function(pt) {
  round(pt * 96 / 72) # Standard conversion: 96 DPI screen, 72 points per inch
}

create_temperature_plots <- function(
  # Core identifiers and paths
  id,
  input_dir,
  output_dir = "./output_plots",
  # --- General Plot Parameters ---
  font_family = "Roboto", # Defaulting to Roboto as in the script
  color_text_primary = "grey30",
  color_text_secondary = "grey40",
  color_caption_text = "grey45",
  color_grid_lines = "grey80",
  color_title = "black", # New variable for title color
  color_subtitle = "black", # New variable for subtitle color
  year_to_highlight = 2024,
  # --- Line Chart Specific Parameters ---
  linechart_width_in = 7,
  linechart_height_in = 7,
  linechart_dpi = 300,
  lc_base_font_size_pt = 12,
  lc_title_pt = 20,
  lc_subtitle_pt = 15,
  lc_axis_title_pt = 15,
  lc_axis_text_pt = 15,
  lc_caption_pt = 12,
  lc_legend_text_pt = 12,
  lc_color_yearly_jul = "#fa6847",
  lc_color_smoothed_jul = "black",
  lc_point_size = 1.5,
  lc_line_width = 1.4,
  lc_plot_margin_t = 5,
  lc_plot_margin_r = 5,
  lc_plot_margin_b = 5,
  lc_plot_margin_l = 5,
  lc_y_axis_padding_lower = 1.0,
  lc_y_axis_padding_upper = 1.8,
  lc_num_y_breaks = 4,
  lc_num_x_breaks = 3,
  lc_highlight_point_size_factor = 3.5,
  lc_highlight_point_stroke = 1.2,
  lc_highlight_label_text_size_mm = 5.5,
  lc_x_breaks = c(1950, 1975, 2000, 2025) # New parameter for custom x-axis breaks
) {
  # --- 0. Setup and Data Loading ---
  cli::cli_h1(paste0("Generating plots for ID: ", id))

  station_output_dir <- file.path(output_dir, id)
  if (!dir.exists(station_output_dir)) {
    dir.create(station_output_dir, recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info(
      "Created output directory: {.path {station_output_dir}}"
    )
  }

  # Regex from your provided script. IMPORTANT: This looks for filenames containing "id<number>_", e.g., "data_id105_file.csv"
  # If your filenames are different (e.g., "wien_hohe_warte_105.csv"), this regex will need adjustment.
  file_regex_pattern <- paste0(".*id", id, "_.*\\.csv")

  potential_files <- list.files(
    path = input_dir,
    pattern = file_regex_pattern,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(potential_files) == 0) {
    cli::cli_abort(c(
      "No input file found in {.path {input_dir}} for ID {.val {id}}.",
      "i" = "Pattern used: {.str {file_regex_pattern}}"
    ))
  }
  if (length(potential_files) > 1) {
    cli::cli_warn(c(
      "Multiple files found for ID {.val {id}}. Using the first one:",
      "i" = "{.path {potential_files[1]}}",
      "i" = "Pattern used: {.str {file_regex_pattern}}"
    ))
  }
  input_file_path <- potential_files[1]
  cli::cli_alert_info("Loading data from: {.path {input_file_path}}")

  d_raw <- tryCatch(
    {
      readr::read_csv(input_file_path, show_col_types = FALSE)
    },
    error = function(e) {
      cli::cli_abort(c(
        "Failed to read CSV file: {.path {input_file_path}}.",
        "x" = e$message
      ))
      return(NULL)
    }
  )

  if (is.null(d_raw)) {
    return(invisible(NULL)) # Return NULL if data loading fails
  }

  required_cols <- c("station_name", "year", "Jul", "Jul_5yr_avg")
  missing_cols <- setdiff(required_cols, names(d_raw))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "Input file {.path {input_file_path}} is missing required columns:",
      "x" = paste(missing_cols, collapse = ", ")
    ))
  }

  plot_data_annual_jul <- d_raw %>%
    dplyr::select(station_name, year, temperature = Jul) %>%
    dplyr::mutate(average_type = "Jährlich (Juli)") %>%
    dplyr::filter(!is.na(temperature))

  plot_data_5yr_jul <- d_raw %>%
    dplyr::select(station_name, year, temperature = Jul_5yr_avg) %>%
    dplyr::mutate(average_type = "5-Jahres Glättung (Juli)") %>%
    dplyr::filter(!is.na(temperature))

  plot_data_jul <- dplyr::bind_rows(plot_data_annual_jul, plot_data_5yr_jul)

  if (nrow(plot_data_jul) == 0) {
    cli::cli_warn(
      "Data for plotting (`plot_data_jul`) is empty after processing. Skipping plots."
    )
    return(NULL) # Return NULL if plots cannot be generated
  }

  min_start_year <- min(plot_data_jul$year, na.rm = TRUE)
  max_end_year <- max(plot_data_jul$year, na.rm = TRUE)

  if (
    !is.finite(min_start_year) ||
      !is.finite(max_end_year) ||
      min_start_year > max_end_year
  ) {
    cli::cli_warn(
      "Could not determine a valid year range from data (min: {min_start_year}, max: {max_end_year}). Skipping plots."
    )
    return(NULL)
  }

  current_station_name <- unique(plot_data_jul$station_name)[1]
  if (is.na(current_station_name) || length(current_station_name) == 0) {
    current_station_name <- "Unbekannte Station"
    cli::cli_warn(
      "`current_station_name` could not be determined. Using default: '{current_station_name}'."
    )
  }

  lc_title_px_ggtext <- .pt_to_px(lc_title_pt)
  lc_subtitle_px_ggtext <- .pt_to_px(lc_subtitle_pt)
  lc_highlight_point_size <- lc_point_size * lc_highlight_point_size_factor

  # --- 1. Line Chart ---
  cli::cli_h2("Generating Line Chart for {current_station_name}")

  highlighted_temp_value <- -Inf
  highlight_data <- plot_data_jul %>%
    dplyr::filter(average_type == "Jährlich (Juli)" & year == year_to_highlight)
  if (nrow(highlight_data) > 0 && !is.na(highlight_data$temperature[1])) {
    highlighted_temp_value <- highlight_data$temperature[1]
  }

  y_lim_max_val <- max(
    c(plot_data_jul$temperature, 20.5, highlighted_temp_value),
    na.rm = TRUE
  )
  y_lim_min_val <- min(plot_data_jul$temperature, na.rm = TRUE)

  if (!is.finite(y_lim_max_val)) y_lim_max_val <- 25 # Fallback
  if (!is.finite(y_lim_min_val)) y_lim_min_val <- 10 # Fallback

  # Calculate nice breaks for y-axis
  y_breaks <- pretty(c(y_lim_min_val, y_lim_max_val), n = lc_num_y_breaks)
  y_breaks <- y_breaks[y_breaks >= y_lim_min_val & y_breaks <= y_lim_max_val]

  plot_line <- ggplot2::ggplot(
    plot_data_jul,
    ggplot2::aes(x = year, y = temperature)
  ) +
    ggplot2::geom_point(
      data = . %>% dplyr::filter(average_type == "Jährlich (Juli)"),
      size = lc_point_size,
      alpha = 0.8,
      ggplot2::aes(color = average_type),
      key_glyph = "point"
    ) +
    ggplot2::geom_point(
      data = . %>%
        dplyr::filter(
          average_type == "Jährlich (Juli)" & year == year_to_highlight
        ),
      size = lc_highlight_point_size,
      color = lc_color_yearly_jul,
      shape = 1,
      stroke = lc_highlight_point_stroke
    ) +
    ggtext::geom_richtext(
      data = . %>%
        dplyr::filter(
          average_type == "Jährlich (Juli)" & year == year_to_highlight
        ),
      ggplot2::aes(
        label = glue::glue(
          "<span style='color:{color_caption_text};'>{year_to_highlight}</span><br><span style='color:{lc_color_yearly_jul};'>{sprintf('%.1f°C', temperature)}</span>"
        )
      ),
      vjust = -0.6,
      hjust = 0.5,
      size = lc_highlight_label_text_size_mm,
      family = font_family,
      fontface = "bold",
      label.padding = ggplot2::unit(c(0, 0, 0, 0), "lines"),
      label.r = ggplot2::unit(0, "lines"),
      label.size = 0,
      fill = NA
    ) +
    ggplot2::geom_line(
      data = . %>% dplyr::filter(average_type == "5-Jahres Glättung (Juli)"),
      linewidth = lc_line_width,
      ggplot2::aes(color = average_type),
      key_glyph = "timeseries"
    ) +
    # ggplot2::geom_smooth(...) REMOVED for Loess Trend
    ggplot2::scale_color_manual(
      name = NULL,
      values = c(
        "Jährlich (Juli)" = lc_color_yearly_jul,
        "5-Jahres Glättung (Juli)" = lc_color_smoothed_jul
      ),
      labels = c(
        "Jährlich (Juli)" = glue::glue(
          "<span style='color:{lc_color_yearly_jul};'>Juli-Durchschitt (einzelnes Jahr)</span>"
        ),
        "5-Jahres Glättung (Juli)" = glue::glue(
          "<span style='color:{lc_color_smoothed_jul};'>5-J. Mittel</span>"
        )
      )
    ) +
    # ggplot2::scale_linetype_manual(...) REMOVED for Loess Trend
    ggplot2::scale_y_continuous(
      breaks = y_breaks,
      labels = function(x) {
        ifelse(x == max(y_breaks), paste0(x, "°C"), as.character(x))
      }
    ) +
    ggplot2::scale_x_continuous(breaks = lc_x_breaks) +
    ggplot2::coord_cartesian(
      xlim = c(min_start_year - 1, max_end_year + 1),
      ylim = c(
        y_lim_min_val - lc_y_axis_padding_lower,
        y_lim_max_val + lc_y_axis_padding_upper
      ),
      clip = "off"
    ) +
    ggplot2::labs(
      title = glue::glue(
        "<span style='font-family:{font_family}; font-weight:normal; font-size:{lc_title_px_ggtext}px; color:{color_title};'><b style='font-family: Roboto-Bold;'>Julinächte</b> werden immer wärmer</span>"
      ),
      subtitle = glue::glue(
        "<span style='font-family:{font_family}; font-size:{lc_subtitle_px_ggtext}px; color:{color_subtitle};'>Durchschnittliche Nachttemperatur im Juli <b style='font-family:Roboto-Bold;'>seit {min_start_year}</b><br>Gemessen an der Station <b style='font-family:Roboto-Bold;'>{current_station_name}</b></span>"
      ),
      x = NULL,
      y = NULL,
      caption = glue::glue(
        # Caption updated to remove Loess trend
        "<b style='font-family:{font_family}; color:{color_text_primary};'>5-Jahres-Schnitt:</b> <i style='color:{color_text_secondary};'>Gleitender Durchschnitt über 5 Jahre.</i><br>",
        "<b style='font-family:{font_family}; color:{color_text_primary};'>Daten:</b> <i style='color:{color_text_secondary};'>Geosphere Stationsdaten  (Nacht: 22:00-05:59 Uhr)</i><br>",
        "<span style='color:{color_text_primary};'>rk</span><i style='color:{color_text_secondary};'> für das Netzwerk Klimajournalismus, Juni 2025</i>"
      )
    ) +
    ggplot2::guides(
      color = ggplot2::guide_legend(override.aes = list(label = ""))
    ) + # linetype guide removed
    ggplot2::theme_minimal(
      base_size = lc_base_font_size_pt,
      base_family = font_family
    ) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(
        fill = "transparent",
        colour = NA
      ),
      panel.background = ggplot2::element_rect(
        fill = "transparent",
        colour = NA
      ),
      legend.background = ggplot2::element_rect(
        fill = "transparent",
        colour = NA
      ),
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.title = ggtext::element_markdown(
        hjust = 0.0,
        margin = ggplot2::margin(b = 10),
        lineheight = 1.1
      ),
      plot.subtitle = ggtext::element_markdown(
        hjust = 0.0,
        margin = ggplot2::margin(b = -30),
        lineheight = 1.6
      ),
      axis.title.x = ggplot2::element_blank(),
      axis.title.y = ggtext::element_markdown(
        margin = ggplot2::margin(r = 5),
        size = ggplot2::rel(lc_axis_title_pt / lc_base_font_size_pt)
      ),
      axis.text = ggplot2::element_text(
        colour = color_text_secondary,
        size = ggplot2::rel(lc_axis_text_pt / lc_base_font_size_pt)
      ),
      axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 2)),
      axis.text.y = ggplot2::element_text(hjust = 1),
      plot.caption = ggtext::element_markdown(
        hjust = 0,
        margin = ggplot2::margin(t = 15),
        size = ggplot2::rel(lc_caption_pt / lc_base_font_size_pt),
        lineheight = 1.3,
        colour = color_caption_text
      ),
      plot.caption.position = "plot",
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.text = ggtext::element_markdown(
        size = ggplot2::rel(lc_legend_text_pt / lc_base_font_size_pt)
      ),
      legend.margin = ggplot2::margin(t = 0, r = 0, b = 0, l = 0),
      legend.spacing.x = ggplot2::unit(0.2, "cm"),
      legend.title = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(
        colour = color_grid_lines,
        linewidth = 0.3
      ),
      panel.spacing = ggplot2::unit(0, "lines"),
      panel.ontop = TRUE,
      plot.margin = ggplot2::margin(
        t = lc_plot_margin_t,
        r = lc_plot_margin_r,
        b = lc_plot_margin_b,
        l = lc_plot_margin_l,
        unit = "pt"
      )
    )

  linechart_filename <- file.path(
    station_output_dir,
    paste0(id, "_linechart.png")
  )
  ggplot2::ggsave(
    filename = linechart_filename,
    plot = plot_line,
    device = png, # Explicitly using "png" device
    width = linechart_width_in,
    height = linechart_height_in,
    units = "in",
    dpi = linechart_dpi,
    bg = "transparent"
  )
  cli::cli_alert_success("Line chart saved: {.path {linechart_filename}}")

  cli::cli_alert_success("Finished processing for ID: {.val {id}}")
  return(plot_line) # Return only the line plot
}


# ++++++++++++++++++++++++++++++
# create plots ----
# ++++++++++++++++++++++++++++++

input_dir <- file.path(
  sys_get_script_dir(),
  "data_raw",
  "processed",
  "tropennächte",
  "dw"
)
output_dir <- davR::sys_make_path(file.path(
  sys_get_script_dir(),
  "images/tropennächte"
))

color_text_primary <- "grey30"
color_text_secondary <- "grey40"
color_caption_text <- "grey45"
color_grid_lines <- "grey80"
color_title <- "black" # New variable for title color
color_subtitle <- "black" # New variable for subtitle color

plot <- create_temperature_plots(
  "105",
  input_dir = input_dir,
  output_dir = output_dir,
  lc_color_yearly_jul = color_caption_text,
  lc_color_smoothed_jul = "#A40f15",
  lc_x_breaks = c(1940, 1960, 1980, 2000, 2020),
  lc_axis_text_pt = 22,
  lc_axis_title_pt = 17,
  lc_legend_text_pt = 17,
  color_title = color_title,
  color_subtitle = color_subtitle
)

plot_innere_stadt <- create_temperature_plots(
  "5925",
  input_dir = input_dir,
  output_dir = output_dir,
  color_title = color_title,
  color_subtitle = color_subtitle
)

# To see the plot if run interactively (and it was generated successfully)
# if (!is.null(plot)) print(plot)
