library(tidyverse) # For data manipulation (dplyr, ggplot2, etc.) and pipes (%>%)
library(glue) # For easy string interpolation
# library(davR) # Assuming sys_make_path is available or path is set directly for output_images_path
library(here) # For robust path construction relative to project root
# library(sf) # For spatial data operations (used for st_drop_geometry, if needed elsewhere)
library(ggtext) # For markdown/HTML in ggplot2 text (e.g., titles)
library(zoo) # For rolling mean calculation (rollmean)
library(lubridate) # For date-time manipulation
# library(data.table) # For fast file reading (fread)
library(cli) # For styled command-line messages
library(scales) # For pretty_breaks
# library(ragg) # For ragg::agg_png if used

# --- 0. Data Loading and Preparation ---
# Placeholder for davR function if not available
if (!exists("sys_make_path", where = "package:davR", mode = "function")) {
  sys_make_path <- function(...) file.path(...)
  sys_get_script_dir <- function() "." # Or getwd()
  cli::cli_warn("`davR` or its functions not found. Using basic `file.path()` and current directory for `sys_get_script_dir()`.")
}

output_images_path <- sys_make_path(sys_get_script_dir(), "images/tropennächte_highlighted")
if (!exists("data_raw_path_hourly_data_processed")) {
  data_raw_path_hourly_data_processed <- tempdir()
  cli::cli_warn("`data_raw_path_hourly_data_processed` not defined. Using temp directory.")
}

if (!exists("d_whw")) {
  cli::cli_warn("`d_whw` not found. Creating dummy data for demonstration.")
  set.seed(123)
  years_data <- 1941:2024
  d_whw_temp <- tibble(
    station_name = "Wien Hohe Warte",
    year = years_data,
    Jul = round(17 + (years_data - 1940) * 0.05 + rnorm(length(years_data), 0, 0.8), 1),
    Jul_5yr_avg = NA_real_
  )
  d_whw_temp <- d_whw_temp %>%
    arrange(year) %>%
    mutate(Jul_5yr_avg = zoo::rollmean(Jul, k = 5, fill = NA, align = "right"))
  d_whw <- d_whw_temp
}


if (!exists("d_whw")) {
  stop("`d_whw` is not defined. Please load your data first.")
}

plot_data_annual_jul <- d_whw %>%
  select(station_name, year, temperature = Jul) %>%
  mutate(average_type = "Jährlich (Juli)") %>%
  filter(!is.na(temperature))

plot_data_5yr_jul <- d_whw %>%
  select(station_name, year, temperature = Jul_5yr_avg) %>%
  mutate(average_type = "5-Jahres Glättung (Juli)") %>%
  filter(!is.na(temperature))

plot_data_jul <- bind_rows(plot_data_annual_jul, plot_data_5yr_jul)

if (nrow(plot_data_jul) == 0) {
  stop("`plot_data_jul` is empty after processing `d_whw`. Check `d_whw` and processing steps.")
}
min_start_year <- min(plot_data_jul$year, na.rm = TRUE)
max_end_year <- max(plot_data_jul$year, na.rm = TRUE)
current_station_name <- unique(plot_data_jul$station_name)[1]
if (is.na(current_station_name) || length(current_station_name) == 0) {
  current_station_name <- "Unbekannte Station"
  cli::cli_warn("`current_station_name` could not be determined. Using default.")
}

# --- 1. Define Font Sizes (in Points) and Other Parameters ---
pt_to_px <- function(pt) round(pt * 96 / 72)

base_font_size_pt_for_theme_minimal <- 12
title_pt <- 20
subtitle_pt <- 15
axis_title_pt <- 15
axis_text_pt <- 15
caption_pt <- 15
legend_text_pt <- 12

title_px_ggtext <- pt_to_px(title_pt)
subtitle_px_ggtext <- pt_to_px(subtitle_pt)

color_yearly_jul <- "#fa6847"
color_smoothed_jul <- "black"
color_loess <- "#9cc9e0"
color_text_primary <- "grey30"
color_text_secondary <- "grey40"
color_caption_text <- "grey45"
color_grid_lines <- "grey80"

point_size <- 1.5
line_width <- 1.4
smooth_line_width <- 1.4
plot_margin_obj <- ggplot2::margin(t = 5, r = 5, b = 5, l = 5, unit = "pt")
y_axis_padding_lower <- 1.0
y_axis_padding_upper <- 1.8
num_y_breaks <- 4
num_x_breaks <- 3

year_to_highlight <- 2024
highlight_point_size <- point_size * 3.5
highlight_point_stroke <- 1.2
highlight_label_text_size_mm <- 4.2

# ++++++++++++++++++++++++++++++
# Line Chart ----
# ++++++++++++++++++++++++++++++

plot <- ggplot(plot_data_jul, aes(x = year, y = temperature)) +
  geom_point(
    data = . %>% filter(average_type == "Jährlich (Juli)"),
    size = point_size, alpha = 0.8, aes(color = average_type), key_glyph = "point"
  ) +
  geom_point(
    data = . %>% filter(average_type == "Jährlich (Juli)" & year == year_to_highlight),
    aes(x = year, y = temperature),
    size = highlight_point_size,
    color = color_yearly_jul,
    shape = 1,
    stroke = highlight_point_stroke
  ) +
  geom_text(
    data = . %>% filter(average_type == "Jährlich (Juli)" & year == year_to_highlight),
    aes(label = sprintf("%.1f°C", temperature)),
    vjust = -1.3,
    hjust = 0.5,
    size = highlight_label_text_size_mm,
    color = color_yearly_jul,
    family = "roboto",
    fontface = "bold",
    check_overlap = TRUE
  ) +
  geom_line(
    data = . %>% filter(average_type == "5-Jahres Glättung (Juli)"),
    linewidth = line_width, aes(color = average_type), key_glyph = "timeseries"
  ) +
  geom_smooth(
    data = . %>% filter(average_type == "Jährlich (Juli)"),
    method = "loess", se = FALSE, linewidth = smooth_line_width,
    colour = color_loess, aes(linetype = "Loess Trend"), key_glyph = "timeseries"
  ) +
  scale_color_manual(
    name = NULL,
    values = c(
      "Jährlich (Juli)" = color_yearly_jul,
      "5-Jahres Glättung (Juli)" = color_smoothed_jul
    ),
    labels = c(
      "Jährlich (Juli)" = glue("<span style='color:{color_yearly_jul};'>jährliches Mittel</span>"), # <<-- MODIFIED HERE
      "5-Jahres Glättung (Juli)" = glue("<span style='color:{color_smoothed_jul};'>5-J. Mittel</span>")
    )
  ) +
  scale_linetype_manual(
    name = NULL,
    values = c("Loess Trend" = "dashed"),
    labels = c("Loess Trend" = glue("<span style='color:{color_loess};'>Loess Trend</span>"))
  ) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = num_y_breaks)) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = num_x_breaks)) +
  coord_cartesian(
    xlim = c(min_start_year - 1, max_end_year + 1),
    ylim = c(
      min(plot_data_jul$temperature, na.rm = TRUE) - y_axis_padding_lower,
      max(plot_data_jul$temperature, 20.5, na.rm = TRUE) + y_axis_padding_upper
    ),
    clip = "off"
  ) +
  labs(
    title = glue("<span style='font-weight: 200; font-size:{title_px_ggtext}px; color:{color_text_primary};'><b style='font-family: Roboto-Bold;'>Julinächte</b> werden immer wärmer</span>"),
    subtitle = glue(
      "<span style='font-size:{subtitle_px_ggtext}px; color:{color_text_secondary};'>",
      "Durchschnittliche Nachttemperatur im Juli seit <span style='font-family: Roboto-Bold;'>{min_start_year}</span><br>",
      "Gemessen an der Station: <span style='font-family: Roboto-Bold;'>{current_station_name}</span><br>",
      "</span>"
    ),
    x = NULL,
    y = glue("<span style='font-size:{pt_to_px(axis_title_pt)}px; color:{color_text_primary};'>Temperatur (°C)</span>"),
    caption = glue("
  <b style='font-family: Roboto-Bold; color:{color_text_primary};'>5-Jahres-Schnitt:</b>
  <i style='color:{color_text_primary};'> Durchschnitt der jährlichen Nachttemperaturen<br>über 5 Jahre – geglättet zur Reduktion kurzfristiger Schwankungen.</i><br>
  <b style='font-family: Roboto-Bold; color:{color_text_primary};'>Loess-Trend:</b>
  <i style='color:{color_text_primary};'> Lokal gewichtete Regression zur Visualisierung<br>langfristiger Entwicklungen.</i><br>
  <b style='font-family: Roboto-Bold; color:{color_text_primary};'>Daten:</b><i style='color:{color_text_primary};'> Geosphere Stationsdaten (Messstationen Stundendaten v2) | KJN</i><br>
  <b style='font-family: Roboto-Bold; color:{color_text_primary};'>Nacht:</b><i style='color: {color_text_primary}'> definiert als 22:00 - 05:59 Uhr</i>
")
  ) +
  guides(
    color = guide_legend(override.aes = list(label = "")),
    linetype = guide_legend(override.aes = list(label = ""))
  ) +
  theme_minimal(base_size = base_font_size_pt_for_theme_minimal, base_family = "roboto") +
  theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    legend.background = element_rect(fill = "transparent", colour = NA),
    legend.key = element_rect(fill = "transparent", colour = NA),
    plot.title = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 10), lineheight = 1.1),
    plot.subtitle = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 15), lineheight = 1.6),
    axis.title.x = element_blank(),
    axis.title.y = element_markdown(margin = ggplot2::margin(r = 5), size = axis_title_pt),
    axis.text = element_text(colour = color_text_secondary, size = axis_text_pt),
    axis.text.x = element_text(margin = ggplot2::margin(t = 2)),
    axis.text.y = element_text(margin = ggplot2::margin(r = 2)),
    plot.caption = element_markdown(
      hjust = 0, margin = ggplot2::margin(t = 10),
      size = caption_pt, lineheight = 1.3
    ),
    plot.caption.position = "plot",
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.text = element_markdown(size = legend_text_pt),
    legend.margin = ggplot2::margin(t = 10, r = 0, b = 0, l = 0),
    legend.spacing.x = unit(0.2, "cm"),
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = color_grid_lines, linewidth = 0.3),
    plot.margin = plot_margin_obj
  )

# --- 3. Save the Plot ---
if (!exists("output_images_path") || is.null(output_images_path)) {
  output_images_path <- here::here("output_images_tropennachte_highlighted")
  cli::cli_alert_info("`output_images_path` was not set. Using default: {output_images_path}")
}
dir.create(output_images_path, recursive = TRUE, showWarnings = FALSE)

email_width_px <- 750
email_aspect_ratio <- 5.5 / 7
email_height_px <- round(email_width_px * email_aspect_ratio) + 30
email_dpi <- 300

fn_email_transparent_highlighted <- file.path(output_images_path, "juli_nachttemperatur_trend_highlighted2024_legend_updated.png") # Updated filename slightly

ggsave(fn_email_transparent_highlighted,
  plot = plot,
  device = "png",
  width = 7,
  height = 7,
  units = "in",
  dpi = email_dpi,
  bg = "transparent"
)

cli::cli_alert_success("Plot with updated legend saved: {fn_email_transparent_highlighted}")

# To display the plot in RStudio Viewer (optional):
# print(plot)
