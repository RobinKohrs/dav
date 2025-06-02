# Helper function to convert points to pixels for ggtext (internal)
.pt_to_px <- function(pt) {
  round(pt * 96 / 72) # Standard conversion: 96 DPI screen, 72 points per inch
}

create_temperature_plots <- function(
    # Core identifiers and paths
    id,
    input_dir,
    output_dir = "./output_plots",
    file_pattern_prefix = "",
    file_pattern_suffix = "", # Default to .csv files
    # --- General Plot Parameters ---
    font_family = "Roboto", # Defaulting to Roboto as in the script
    color_text_primary = "grey30",
    color_text_secondary = "grey40",
    color_caption_text = "grey45",
    color_grid_lines = "grey80",
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
    lc_color_loess = "#9cc9e0",
    lc_point_size = 1.5,
    lc_line_width = 1.4,
    lc_smooth_line_width = 1.4,
    lc_plot_margin_t = 5, lc_plot_margin_r = 5, lc_plot_margin_b = 5, lc_plot_margin_l = 5,
    lc_y_axis_padding_lower = 1.0,
    lc_y_axis_padding_upper = 1.8,
    lc_num_y_breaks = 4,
    lc_num_x_breaks = 3,
    lc_highlight_point_size_factor = 3.5,
    lc_highlight_point_stroke = 1.2,
    lc_highlight_label_text_size_mm = 4.2,
    # --- Bar Chart Specific Parameters ---
    barchart_width_in = 7,
    barchart_height_in = 5.5,
    barchart_dpi = 300,
    bc_base_font_size_pt = 12,
    bc_title_pt = 18,
    bc_subtitle_pt = 12,
    bc_axis_title_pt = 15,
    bc_axis_text_pt = 15,
    bc_axis_text_x_pt = 10,
    bc_caption_pt = 10,
    bc_bar_color_decade = "black", # Was color_smoothed_jul
    bc_bar_text_color_on_bar = "grey30", # Was color_text_primary
    bc_bar_label_size_mm = 3,
    bc_num_y_breaks = 4,
    bc_plot_margin_t = 15, bc_plot_margin_r = 20, bc_plot_margin_b = 15, bc_plot_margin_l = 10) {
  # --- 0. Setup and Data Loading ---
  cli::cli_h1(paste0("Generating plots for ID: ", id))

  station_output_dir <- file.path(output_dir, id)
  if (!dir.exists(station_output_dir)) {
    dir.create(station_output_dir, recursive = TRUE, showWarnings = FALSE)
    cli::cli_alert_info("Created output directory: {.path {station_output_dir}}")
  }

  # Construct regex: (prefix_literal ".*" | ".*") id ".*" suffix_regex
  file_regex_pattern <- paste0(
    ".*id",
    id,
    "_.*\\.csv"
  )

  potential_files <- list.files(
    path = input_dir,
    pattern = file_regex_pattern,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(potential_files) == 0) {
    cli::cli_abort(c("No input file found in {.path {input_dir}} for ID {.val {id}}.",
      "i" = "Pattern used: {.str {file_regex_pattern}}"
    ))
  }
  if (length(potential_files) > 1) {
    cli::cli_warn(c("Multiple files found for ID {.val {id}}. Using the first one:",
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
      cli::cli_abort(c("Failed to read CSV file: {.path {input_file_path}}.",
        "x" = e$message
      ))
      return(NULL)
    }
  )

  if (is.null(d_raw)) {
    return(invisible(NULL))
  }

  required_cols <- c("station_name", "year", "Jul", "Jul_5yr_avg")
  missing_cols <- setdiff(required_cols, names(d_raw))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c("Input file {.path {input_file_path}} is missing required columns:",
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
    cli::cli_warn("Data for plotting (`plot_data_jul`) is empty after processing. Skipping plots.")
    return(invisible(NULL))
  }

  min_start_year <- min(plot_data_jul$year, na.rm = TRUE)
  max_end_year <- max(plot_data_jul$year, na.rm = TRUE)

  if (!is.finite(min_start_year) || !is.finite(max_end_year) || min_start_year > max_end_year) {
    cli::cli_warn("Could not determine a valid year range from data (min: {min_start_year}, max: {max_end_year}). Skipping plots.")
    return(invisible(NULL))
  }

  current_station_name <- unique(plot_data_jul$station_name)[1]
  if (is.na(current_station_name) || length(current_station_name) == 0) {
    current_station_name <- "Unbekannte Station"
    cli::cli_warn("`current_station_name` could not be determined. Using default: '{current_station_name}'.")
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

  y_lim_max_val <- max(c(plot_data_jul$temperature, 20.5, highlighted_temp_value), na.rm = TRUE)
  y_lim_min_val <- min(plot_data_jul$temperature, na.rm = TRUE)

  if (!is.finite(y_lim_max_val)) y_lim_max_val <- 25 # Fallback
  if (!is.finite(y_lim_min_val)) y_lim_min_val <- 10 # Fallback


  plot_line <- ggplot2::ggplot(plot_data_jul, ggplot2::aes(x = year, y = temperature)) +
    ggplot2::geom_point(
      data = . %>% dplyr::filter(average_type == "Jährlich (Juli)"),
      size = lc_point_size, alpha = 0.8, ggplot2::aes(color = average_type), key_glyph = "point"
    ) +
    ggplot2::geom_point(
      data = . %>% dplyr::filter(average_type == "Jährlich (Juli)" & year == year_to_highlight),
      size = lc_highlight_point_size,
      color = lc_color_yearly_jul,
      shape = 1,
      stroke = lc_highlight_point_stroke
    ) +
    ggplot2::geom_text(
      data = . %>% dplyr::filter(average_type == "Jährlich (Juli)" & year == year_to_highlight),
      ggplot2::aes(label = sprintf("%.1f°C", temperature)),
      vjust = -1.3, hjust = 0.5, size = lc_highlight_label_text_size_mm,
      color = lc_color_yearly_jul, family = font_family, fontface = "bold", check_overlap = TRUE
    ) +
    ggplot2::geom_line(
      data = . %>% dplyr::filter(average_type == "5-Jahres Glättung (Juli)"),
      linewidth = lc_line_width, ggplot2::aes(color = average_type), key_glyph = "timeseries"
    ) +
    ggplot2::geom_smooth(
      data = . %>% dplyr::filter(average_type == "Jährlich (Juli)"),
      method = "loess", formula = y ~ x, se = FALSE, linewidth = lc_smooth_line_width,
      colour = lc_color_loess, ggplot2::aes(linetype = "Loess Trend"), key_glyph = "timeseries"
    ) +
    ggplot2::scale_color_manual(
      name = NULL,
      values = c("Jährlich (Juli)" = lc_color_yearly_jul, "5-Jahres Glättung (Juli)" = lc_color_smoothed_jul),
      labels = c(
        "Jährlich (Juli)" = glue::glue("<span style='color:{lc_color_yearly_jul};'>jährliches Mittel</span>"),
        "5-Jahres Glättung (Juli)" = glue::glue("<span style='color:{lc_color_smoothed_jul};'>5-J. Mittel</span>")
      )
    ) +
    ggplot2::scale_linetype_manual(
      name = NULL,
      values = c("Loess Trend" = "dashed"),
      labels = c("Loess Trend" = glue::glue("<span style='color:{lc_color_loess};'>Loess Trend</span>"))
    ) +
    ggplot2::scale_y_continuous(breaks = scales::pretty_breaks(n = lc_num_y_breaks)) +
    ggplot2::scale_x_continuous(breaks = scales::pretty_breaks(n = lc_num_x_breaks)) +
    ggplot2::coord_cartesian(
      xlim = c(min_start_year - 1, max_end_year + 1),
      ylim = c(
        y_lim_min_val - lc_y_axis_padding_lower,
        y_lim_max_val + lc_y_axis_padding_upper
      ),
      clip = "off"
    ) +
    ggplot2::labs(
      title = glue::glue("<span style='font-family:{font_family}; font-weight:normal; font-size:{lc_title_px_ggtext}px; color:{color_text_primary};'><b>Julinächte</b> werden immer wärmer</span>"),
      subtitle = glue::glue("<span style='font-family:{font_family}; font-size:{lc_subtitle_px_ggtext}px; color:{color_text_secondary};'>Durchschnittliche Nachttemperatur im Juli seit <b>{min_start_year}</b><br>Gemessen an der Station: <b>{current_station_name}</b></span>"),
      x = NULL,
      y = glue::glue("<span style='font-family:{font_family}; font-size:{.pt_to_px(lc_axis_title_pt)}px; color:{color_text_primary};'>Temperatur (°C)</span>"),
      caption = glue::glue(
        "<b style='font-family:{font_family}; color:{color_text_primary};'>5-Jahres-Schnitt:</b> <i style='color:{color_text_secondary};'>Gleitender Durchschnitt über 5 Jahre.</i><br>",
        "<b style='font-family:{font_family}; color:{color_text_primary};'>Loess-Trend:</b> <i style='color:{color_text_secondary};'>Langfristige Entwicklung (lokal gewichtete Regression).</i><br>",
        "<b style='font-family:{font_family}; color:{color_text_primary};'>Daten:</b> <i style='color:{color_text_secondary};'>Geosphere Stationsdaten | KJN (Nacht: 22:00-05:59 Uhr)</i>"
      )
    ) +
    ggplot2::guides(color = ggplot2::guide_legend(override.aes = list(label = "")), linetype = ggplot2::guide_legend(override.aes = list(label = ""))) +
    ggplot2::theme_minimal(base_size = lc_base_font_size_pt, base_family = font_family) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.title = ggtext::element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 10), lineheight = 1.1),
      plot.subtitle = ggtext::element_markdown(hjust = 0.0, margin = ggplot2::margin(b = -30), lineheight = 1.6),
      axis.title.x = ggplot2::element_blank(),
      axis.title.y = ggtext::element_markdown(margin = ggplot2::margin(r = 5), size = ggplot2::rel(lc_axis_title_pt / lc_base_font_size_pt)),
      axis.text = ggplot2::element_text(colour = color_text_secondary, size = ggplot2::rel(lc_axis_text_pt / lc_base_font_size_pt)),
      axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 2)),
      axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 2)),
      plot.caption = ggtext::element_markdown(hjust = 0, margin = ggplot2::margin(t = 15), size = ggplot2::rel(lc_caption_pt / lc_base_font_size_pt), lineheight = 1.3, colour = color_caption_text),
      plot.caption.position = "plot",
      legend.position = "bottom", legend.box = "horizontal",
      legend.text = ggtext::element_markdown(size = ggplot2::rel(lc_legend_text_pt / lc_base_font_size_pt)),
      legend.margin = ggplot2::margin(t = 0, r = 0, b = 0, l = 0), legend.spacing.x = ggplot2::unit(0.2, "cm"),
      legend.title = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(), panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = color_grid_lines, linewidth = 0.3),
      plot.margin = ggplot2::margin(t = lc_plot_margin_t, r = lc_plot_margin_r, b = lc_plot_margin_b, l = lc_plot_margin_l, unit = "pt")
    )

  linechart_filename <- file.path(station_output_dir, paste0(id, "_linechart.png"))
  ggplot2::ggsave(
    filename = linechart_filename, plot = plot_line, device = png,
    width = linechart_width_in, height = linechart_height_in, units = "in", dpi = linechart_dpi, bg = "transparent"
  )
  cli::cli_alert_success("Line chart saved: {.path {linechart_filename}}")

  # --- 2. Bar Chart ---
  cli::cli_h2("Generating Bar Chart for {current_station_name}")

  if (nrow(plot_data_annual_jul) == 0) {
    cli::cli_warn("`plot_data_annual_jul` is empty. Cannot create decadal bar plot.")
  } else {
    decadal_data <- plot_data_annual_jul %>%
      dplyr::mutate(decade = floor(year / 10) * 10) %>%
      dplyr::group_by(station_name, decade) %>%
      dplyr::summarise(mean_temp_decade = mean(temperature, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(decade_label = glue::glue("{decade}s")) %>%
      dplyr::arrange(decade) %>%
      dplyr::mutate(decade_label = factor(decade_label, levels = unique(decade_label)))

    if (nrow(decadal_data) == 0) {
      cli::cli_warn("`decadal_data` is empty after processing. Skipping bar chart.")
    } else {
      bc_title_px_ggtext <- .pt_to_px(bc_title_pt)
      bc_subtitle_px_ggtext <- .pt_to_px(bc_subtitle_pt)

      plot_bar <- ggplot2::ggplot(decadal_data, ggplot2::aes(x = decade_label, y = mean_temp_decade)) +
        ggplot2::geom_col(fill = bc_bar_color_decade, width = 0.7) +
        ggplot2::geom_text(
          ggplot2::aes(label = sprintf("%.1f", mean_temp_decade)),
          vjust = -0.5, color = bc_bar_text_color_on_bar, size = bc_bar_label_size_mm, family = font_family
        ) +
        ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.12)), breaks = scales::pretty_breaks(n = bc_num_y_breaks)) +
        ggplot2::labs(
          title = glue::glue("<span style='font-family:{font_family}; font-weight:normal; font-size:{bc_title_px_ggtext}px; color:{color_text_primary};'><b>Dekadische Julinächte</b> Temperatur</span>"),
          subtitle = glue::glue("<span style='font-family:{font_family}; font-size:{bc_subtitle_px_ggtext}px; color:{color_text_secondary};'>Mittlere Nachttemperatur pro Dekade im Juli<br>Station: <b>{current_station_name}</b></span>"),
          x = NULL,
          y = glue::glue("<span style='font-family:{font_family}; font-size:{.pt_to_px(bc_axis_title_pt)}px; color:{color_text_primary};'>Mittlere Temperatur (°C)</span>"),
          caption = glue::glue("<b style='font-family:{font_family}; color:{color_text_primary};'>Daten:</b> <i style='color:{color_text_secondary};'>Geosphere Stationsdaten | KJN (Nacht: 22:00-05:59 Uhr)</i>")
        ) +
        ggplot2::theme_minimal(base_size = bc_base_font_size_pt, base_family = font_family) +
        ggplot2::theme(
          plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
          panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
          plot.title = ggtext::element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 8), lineheight = 1.1),
          plot.subtitle = ggtext::element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 12), lineheight = 1.4),
          axis.title.x = ggplot2::element_blank(),
          axis.title.y = ggtext::element_markdown(margin = ggplot2::margin(r = 5), size = ggplot2::rel(bc_axis_title_pt / bc_base_font_size_pt)),
          axis.text = ggplot2::element_text(colour = color_text_secondary),
          axis.text.x = ggplot2::element_text(margin = ggplot2::margin(t = 2), size = ggplot2::rel(bc_axis_text_x_pt / bc_base_font_size_pt), angle = 45, hjust = 1),
          axis.text.y = ggplot2::element_text(margin = ggplot2::margin(r = 2), size = ggplot2::rel(bc_axis_text_pt / bc_base_font_size_pt)),
          plot.caption = ggtext::element_markdown(hjust = 0, margin = ggplot2::margin(t = 10), size = ggplot2::rel(bc_caption_pt / bc_base_font_size_pt), lineheight = 1.3, colour = color_caption_text),
          plot.caption.position = "plot",
          panel.grid.minor = ggplot2::element_blank(), panel.grid.major.x = ggplot2::element_blank(),
          panel.grid.major.y = ggplot2::element_line(colour = color_grid_lines, linewidth = 0.3),
          plot.margin = ggplot2::margin(t = bc_plot_margin_t, r = bc_plot_margin_r, b = bc_plot_margin_b, l = bc_plot_margin_l, unit = "pt")
        )

      barchart_filename <- file.path(station_output_dir, paste0(id, "_barchart.png"))
      ggplot2::ggsave(
        filename = barchart_filename, plot = plot_bar, device = png,
        width = barchart_width_in, height = barchart_height_in, units = "in", dpi = barchart_dpi, bg = "transparent"
      )
      cli::cli_alert_success("Bar chart saved: {.path {barchart_filename}}")
    }
  }

  cli::cli_alert_success("Finished processing for ID: {.val {id}}")
  return(list(line = plot_line, bar = plot_bar))
}

# Example of how to use the function:
# Ensure you have the necessary libraries loaded:
library(tidyverse)
library(glue)
library(ggtext)
library(cli)
library(scales)

# ++++++++++++++++++++++++++++++
# create plots ----
# ++++++++++++++++++++++++++++++


input_dir <- file.path(sys_get_script_dir(), "data_raw", "processed", "tropennächte", "dw")
output_dir <- davR::sys_make_path(file.path(sys_get_script_dir(), "images/tropennächte"))

plots <- create_temperature_plots("105", input_dir = input_dir, output_dir = output_dir)
