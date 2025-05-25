library(tidyverse) # For data manipulation (dplyr, ggplot2, etc.) and pipes (%>%)
library(glue) # For easy string interpolation
library(davR) # For geosphere data access AND sys_make_path
library(here) # For robust path construction relative to project root
library(sf) # For spatial data operations (used for st_drop_geometry)
library(ggtext) # For markdown/HTML in ggplot2 text (e.g., titles)
library(zoo) # For rolling mean calculation (rollmean)
library(lubridate) # For date-time manipulation (month, year, hour, days_in_month)
library(data.table) # For fast file reading (fread)
library(cli) # For styled command-line messages
library(scales) # For pretty_breaks


output_images_path <- davR::sys_make_path(file.path(sys_get_script_dir(), "images/tropennächte"))

path_wien_hohe_warte <- dir(data_raw_path_hourly_data_processed, "wien_hohe_warte.*105", full.names = T)
d_whw <- read_csv(path_wien_hohe_warte)


color_yearly_jul <- "#E69F00"
color_smoothed_jul <- "#56B4E9"
color_loess <- "grey30"
min_start_year <- min(plot_data_jul$year, na.rm = TRUE)
max_end_year <- max(plot_data_jul$year, na.rm = TRUE)


#-------------------------------------
# data
#-------------------------------------
# --- 5. Define "Responsive-Enough" Font Sizes (in Pixels) and Other Parameters ---
# These sizes are chosen to be quite readable on mobile, and will appear large on desktop.
base_font_size_pt_for_theme_minimal <- 11 # Reference for theme_minimal non-text elements

title_size_px <- 22
subtitle_part_size_px <- 15 # For the "Jährlich vs..." part of the title
main_subtitle_size_px <- 13 # For "Nacht definiert als..."
axis_title_size_px <- 14
axis_text_px_size <- 12 # Larger axis text
caption_size_px <- 11
legend_text_px_size <- 12 # Larger legend text
annotate_text_size_ggtext <- 4.2 # ggtext scale, larger for readability

point_size <- 1.6
line_width <- 0.9
smooth_line_width <- 0.7
plot_margin_obj <- ggplot2::margin(t = 12, r = 10, b = 10, l = 10, unit = "pt") # Generous but not excessive
y_axis_limit_expansion <- 1.4
num_y_breaks <- 4 # A moderate number of Y breaks
num_x_breaks <- 3 # Specifically three X-axis breaks

# --- 6. Build the Plot ---
plot <- ggplot(plot_data_jul, aes(x = year, y = temperature)) +
  geom_point(
    data = . %>% filter(average_type == "Jährlich (Juli)"),
    size = point_size, alpha = 0.7, aes(color = average_type), key_glyph = "point"
  ) +
  geom_line(
    data = . %>% filter(average_type == "5-Jahres Glättung (Juli)"),
    linewidth = line_width, aes(color = average_type), key_glyph = "timeseries"
  ) +
  geom_smooth(
    data = . %>% filter(average_type == "Jährlich (Juli)"),
    method = "loess", se = FALSE, linewidth = smooth_line_width,
    colour = color_loess, aes(linetype = "Loess Glättung"), key_glyph = "timeseries"
  ) +
  scale_color_manual(
    name = NULL,
    values = c("Jährlich (Juli)" = color_yearly_jul, "5-Jahres Glättung (Juli)" = color_smoothed_jul),
    labels = c("Jährlich (Juli)" = "Jahresmittel", "5-Jahres Glättung (Juli)" = "5-J. Mittel") # Shorter labels
  ) +
  scale_linetype_manual(
    name = NULL,
    values = c("Loess Glättung" = "dashed"),
    labels = c("Loess Glättung" = "Loess Trend")
  ) +
  geom_hline(yintercept = 20, linetype = "dotted", color = "grey50", linewidth = 0.4) +
  annotate(
    geom = "richtext",
    x = min_start_year + 1, y = 20.25,
    label = "Tropennacht (≥20°C)",
    hjust = 0, vjust = 0, color = "grey20",
    size = annotate_text_size_ggtext,
    label.color = NA, fill = NA, family = "Roboto"
  ) +
  scale_y_continuous(breaks = scales::pretty_breaks(n = num_y_breaks)) +
  scale_x_continuous(breaks = scales::pretty_breaks(n = num_x_breaks)) + # Max 3 breaks
  coord_cartesian(
    xlim = c(min_start_year - 1, max_end_year + 1),
    ylim = c(
      min(plot_data_jul$temperature, na.rm = TRUE) - 1,
      max(plot_data_jul$temperature, 20.5, na.rm = TRUE) + y_axis_limit_expansion
    ),
    clip = "off" # Usually okay if margins are sufficient
  ) +
  labs(
    title = glue::glue(
      "<span style='font-size:{title_size_px}px;'>Nachttemperatur Juli: {unique(plot_data_jul$station_name)}</span><br>",
      "<span style='font-size:{subtitle_part_size_px}px;'>", # Second part of title
      "<span style='color:{color_yearly_jul};'>Jährlich</span> vs <span style='color:{color_smoothed_jul};'>5-J. Glättung</span>",
      "</span>"
    ),
    subtitle = glue::glue("<span style='font-size:{main_subtitle_size_px}px;'>Nacht: 18:00 - 05:59 Uhr</span>"), # Subtitle is kept
    x = NULL, # X-axis title often removed for mobile-first if context is clear
    y = glue::glue("<span style='font-size:{axis_title_size_px}px;'>Temperatur (°C)</span>"),
    caption = glue::glue("<span style='font-size:{caption_size_px}px; color:grey50;'>Daten: Ihre Daten | KJN</span>")
  ) +
  theme_minimal(base_size = base_font_size_pt_for_theme_minimal, base_family = "Roboto") +
  theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    legend.background = element_rect(fill = "transparent", colour = NA),
    legend.key = element_rect(fill = "transparent", colour = NA),
    plot.title = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 5), family = "Roboto", lineheight = 1.1),
    plot.subtitle = element_markdown(hjust = 0.0, margin = ggplot2::margin(b = 12), family = "Roboto", lineheight = 1.0),
    axis.title.x = element_blank(), # Explicitly remove if x lab is NULL
    axis.title.y = element_markdown(margin = ggplot2::margin(r = 5), family = "Roboto", size = axis_title_size_px), # Use the px size
    axis.text = element_markdown(size = axis_text_px_size, family = "Roboto", colour = "grey10"),
    axis.text.x = element_markdown(size = axis_text_px_size, family = "Roboto", colour = "grey10", margin = ggplot2::margin(t = 2)),
    axis.text.y = element_markdown(size = axis_text_px_size, family = "Roboto", colour = "grey10", margin = ggplot2::margin(r = 2)),
    plot.caption = element_markdown(hjust = 1, margin = ggplot2::margin(t = 8), family = "Roboto"),
    legend.position = "top", # Often better for mobile and still okay for desktop
    legend.box = "horizontal",
    legend.text = element_markdown(size = legend_text_px_size, family = "Roboto", colour = "grey10"),
    legend.margin = ggplot2::margin(t = 0, r = 0, b = 5, l = 0), # Adjusted margin for top legend
    legend.spacing.x = unit(0.15, "cm"),
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "grey80", linewidth = 0.3),
    plot.margin = plot_margin_obj
  )


fn_mobile <- file.path(output_images_path, "mobile.png")
fn_desktop <- file.path(output_images_path, "desktop.png")

# Example: Saving for a "general web" size, which might be a good compromise
ggsave(fn_mobile,
  plot = plot, device = png,
  width = 7, height = 5.5, units = "in", dpi = 550, bg = "transparent"
)

# Example: Saving a slightly larger version for "desktop-first" view
ggsave(fn_desktop,
  plot = plot, device = png,
  width = 8.5, height = 6, units = "in", dpi = 300, bg = "transparent"
)
