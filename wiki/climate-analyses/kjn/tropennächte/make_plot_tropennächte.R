library(tidyverse) # For data manipulation (dplyr, ggplot2, etc.) and pipes (%>%)
library(glue) # For easy string interpolation
library(davR) # Assuming sys_make_path is available or path is set directly for output_images_path
library(here) # For robust path construction relative to project root
library(sf) # For spatial data operations (used for st_drop_geometry, if needed elsewhere)
library(ggtext) # For markdown/HTML in ggplot2 text (e.g., titles)
library(zoo) # For rolling mean calculation (rollmean) - still needed for Loess if desired, but not for 5yr avg
library(lubridate) # For date-time manipulation
library(data.table) # For fast file reading (fread)
library(cli) # For styled command-line messages
library(scales) # For pretty_breaks
library(ragg) # For pretty_breaks

# --- 0. Data Loading and Preparation ---
data_raw_path_hourly_data_processed <- file.path(sys_get_script_dir(), "data_raw", "processed", "tropennächte", "dw")
output_images_path <- davR::sys_make_path(file.path(sys_get_script_dir(), "images/tropennächte"))
path_wien_hohe_warte <- dir(data_raw_path_hourly_data_processed, "wien_hohe_warte.*105", full.names = T)
d_whw <- read_csv(path_wien_hohe_warte)

if (!exists("d_whw")) {
  cli::cli_warn("`d_whw` not found. Creating dummy data for demonstration.")
  stop("...")
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
    plot.subtitle = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = -30), lineheight = 1.6),
    axis.title.x = element_blank(),
    axis.title.y = element_markdown(margin = ggplot2::margin(r = 5), size = axis_title_pt),
    axis.text = element_text(colour = color_text_secondary, size = axis_text_pt),
    axis.text.x = element_text(margin = ggplot2::margin(t = 2)),
    axis.text.y = element_text(margin = ggplot2::margin(r = 2)),
    plot.caption = element_markdown(
      hjust = 0, margin = ggplot2::margin(t = 13),
      size = caption_pt, lineheight = 1.3
    ),
    plot.caption.position = "plot",
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.text = element_markdown(size = legend_text_pt),
    legend.margin = ggplot2::margin(t = 0, r = 0, b = 0, l = 0),
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
  device = png,
  width = 7,
  height = 7,
  units = "in",
  dpi = email_dpi,
  bg = "transparent"
)

cli::cli_alert_success("Plot with updated legend saved: {fn_email_transparent_highlighted}")

# To display the plot in RStudio Viewer (optional):
# print(plot)
# ++++++++++++++++++++++++++++++
# Bar plot ----
# ++++++++++++++++++++++++++++++

cli::cli_h1("Generating Decadal Mean Temperature Bar Plot")

# --- 4.1. Calculate Decadal Means ---
# We use plot_data_annual_jul which contains the annual July temperatures.
if (!exists("plot_data_annual_jul") || nrow(plot_data_annual_jul) == 0) {
  stop("`plot_data_annual_jul` is not defined or empty. Cannot create decadal plot.")
}

decadal_data <- plot_data_annual_jul %>%
  mutate(decade = floor(year / 10) * 10) %>%
  group_by(station_name, decade) %>%
  summarise(mean_temp_decade = mean(temperature, na.rm = TRUE), .groups = "drop") %>%
  mutate(decade_label = glue::glue("{decade}s")) %>%
  # Ensure decades are ordered chronologically for the plot
  arrange(decade) %>%
  mutate(decade_label = factor(decade_label, levels = unique(decade_label)))


if (nrow(decadal_data) == 0) {
  stop("`decadal_data` is empty after processing. Check `plot_data_annual_jul`.")
}

# --- 4.2. Define Parameters for Bar Plot (reusing some from the first plot) ---
bar_color_decade <- color_smoothed_jul # Using the dark blue from the first plot
bar_text_color_on_bar <- color_text_primary # Color for text on bars
bar_label_size_mm <- 3 # Size for text on bars (geom_text size is often in mm)

# Font sizes (reusing pt definitions from first plot where appropriate)
bar_title_pt <- 18
bar_subtitle_pt <- 12
# bar_axis_title_pt is already axis_title_pt (12)
# bar_axis_text_pt is already axis_text_pt (12), but we might want it smaller for x-axis if angled
bar_axis_text_x_pt <- 10 # Potentially smaller for angled decade labels
# bar_caption_pt is already caption_pt (10)

bar_title_px_ggtext <- pt_to_px(bar_title_pt)
bar_subtitle_px_ggtext <- pt_to_px(bar_subtitle_pt)

# Station name for subtitle (should be the same as current_station_name)
current_station_name_bar <- unique(decadal_data$station_name)[1]
if (is.na(current_station_name_bar) || length(current_station_name_bar) == 0) {
  current_station_name_bar <- current_station_name # Fallback to previously determined name
  cli::cli_warn("`current_station_name_bar` could not be determined from decadal_data. Using previous.")
}
if (is.na(current_station_name_bar) || length(current_station_name_bar) == 0) {
  current_station_name_bar <- "Unbekannte Station" # Ultimate fallback
}



# --- 4.3. Build the Bar Plot ---
plot_decadal_means <- ggplot(decadal_data, aes(x = decade_label, y = mean_temp_decade)) +
  geom_col(fill = bar_color_decade, width = 0.7) +
  geom_text(
    aes(label = sprintf("%.1f", mean_temp_decade)),
    vjust = -0.5, # Position text slightly above the bar
    color = bar_text_color_on_bar,
    size = bar_label_size_mm # size in mm for geom_text
  ) +
  scale_y_continuous(
    expand = expansion(mult = c(0, 0.12)), # Ensure bars start near 0 and give space for text on top
    breaks = scales::pretty_breaks(n = num_y_breaks) # Reuse num_y_breaks from first plot
  ) +
  labs(
    title = glue("<span style='font-weight: 200; font-size:{bar_title_px_ggtext}px; color:{color_text_primary};'><b style='font-family: Roboto-Bold;'>Dekadische Julinächte</b> Temperatur</span>"),
    subtitle = glue(
      "<span style='font-size:{bar_subtitle_px_ggtext}px; color:{color_text_secondary};'>",
      "Mittlere Nachttemperatur pro Dekade im Juli<br>",
      "Station: <span style='font-family: Roboto-Bold;'>{current_station_name_bar}</span><br>",
      "(Nacht definiert als 22:00 - 05:59 Uhr)", # Consistent night definition
      "</span>"
    ),
    x = NULL, # X-axis title (Decade) is clear from labels
    y = glue("<span style='font-size:{pt_to_px(axis_title_pt)}px; color:{color_text_primary};'>Mittlere Temperatur (°C)</span>"), # Reuse axis_title_pt
    caption = glue("
      <b style='font-family: Roboto-Bold; color:{color_text_primary};'>Daten:</b>
      <i style='color:{color_text_primary};'> Geosphere Stationsdaten (Messstationen Stundendaten v2) | KJN</i>
    ") # Reuse caption_pt
  ) +
  theme_minimal(base_size = base_font_size_pt_for_theme_minimal, base_family = "roboto") + # Reuse from first plot
  theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    plot.title = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 8), lineheight = 1.1),
    plot.subtitle = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 12), lineheight = 1.4),
    axis.title.x = element_blank(),
    axis.title.y = element_markdown(margin = ggplot2::margin(r = 5), size = axis_title_pt), # Reuse axis_title_pt
    axis.text = element_text(colour = color_text_secondary), # General axis text
    axis.text.x = element_text(margin = ggplot2::margin(t = 2), size = bar_axis_text_x_pt, angle = 45, hjust = 1), # Specific for X: smaller, angled
    axis.text.y = element_text(margin = ggplot2::margin(r = 2), size = axis_text_pt), # Reuse axis_text_pt
    plot.caption = element_markdown(
      hjust = 0, margin = ggplot2::margin(t = 8),
      size = caption_pt, lineheight = 1.3 # Reuse caption_pt
    ),
    plot.caption.position = "plot",
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = color_grid_lines, linewidth = 0.3), # Reuse color_grid_lines
    plot.margin = ggplot2::margin(t = 15, r = 20, b = 15, l = 10, unit = "pt") # Adjusted right margin for angled labels
  )

# --- 4.4. Save the Bar Plot ---
# output_images_path should exist from the first plot's setup
if (!exists("output_images_path") || is.null(output_images_path)) {
  # This is a fallback, but it should have been set by the first plot's code.
  output_images_path <- here::here("output_images_tropennachte")
  cli::cli_alert_info("`output_images_path` was not set. Using default for decadal plot: {output_images_path}")
  dir.create(output_images_path, recursive = TRUE, showWarnings = FALSE)
}


fn_decadal_bar_plot <- file.path(output_images_path, "juli_nachttemperatur_dekaden_barplot_sharp.png")

# Using similar saving parameters as the first plot, but adjusting dimensions for a bar chart
bar_plot_width_in <- 7 # inches
bar_plot_height_in <- 5.5 # inches, slightly less tall than wide

ggsave(fn_decadal_bar_plot,
  plot = plot_decadal_means,
  device = png, # Or ragg::agg_png if you prefer ragg for all plots
  width = bar_plot_width_in,
  height = bar_plot_height_in,
  units = "in",
  dpi = email_dpi, # Reuse dpi from first plot
  bg = "transparent"
)

cli::cli_alert_success("Decadal bar plot saved with sharp text: {fn_decadal_bar_plot}")

# Display the plot if in an interactive session (optional)
# print(plot_decadal_means)
