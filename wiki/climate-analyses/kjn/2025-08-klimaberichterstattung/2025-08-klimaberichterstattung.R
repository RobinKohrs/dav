library(tidyverse)
library(glue)
library(sf)
library(davR)
library(jsonlite)
library(readxl)
library(zoo)
library(ggtext)
library(scales)
library(cli)
library(lubridate)
library(svglite)


# ++++++++++++++++++++++++++++++
# load data ----
# ++++++++++++++++++++++++++++++
setwd("~/projects/personal/dav/")
path_data <- "wiki/data_raw/kjn/2025-08-klimaberichterstattung/europe_dataset.xlsx"
raw_data <- read_xlsx(path_data)

years_row <- as.character(raw_data[1, ])
filled_years <- na.locf(years_row[-1])

num_data_cols <- ncol(raw_data) - 1
num_years <- length(unique(filled_years))
month_sequence <- rep(1:12, times = num_years)


new_headers <- c("Newspaper", paste(filled_years, month_sequence, sep = "_"))


data_body <- raw_data[-c(1, 2), ]
colnames(data_body) <- new_headers


data_long <- data_body %>%
  pivot_longer(
    cols = -Newspaper, # Pivot all columns except for 'Newspaper'
    names_to = "year_month", # New column for the "2004_1" headers
    values_to = "Coverage" # New column for the corresponding numeric values
  ) %>%
  # Separate the "year_month" column back into "Year" and "Month"
  separate(year_month, into = c("Year", "Month"), sep = "_") %>%
  # Convert columns to the correct data types (e.g., character to number)
  mutate(
    Year = as.integer(Year),
    Month = as.integer(Month),
    Coverage = as.numeric(Coverage)
  ) %>%
  # Remove any rows that might be completely empty
  filter(!is.na(Coverage))

# Create data_total for plotting
data_total <- data_long %>%
  filter(Newspaper == "Total") %>%
  mutate(date = as.Date(paste(Year, Month, "01", sep = "-"))) %>%
  select(Newspaper, date, Coverage)

# ++++++++++++++++++++++++++++++
# Helper function for pt to px conversion ----
# ++++++++++++++++++++++++++++++
.pt_to_px <- function(pt) {
  round(pt * 96 / 72) # Standard conversion: 96 DPI screen, 72 points per inch
}

# ++++++++++++++++++++++++++++++
# Plot styling parameters ----
# ++++++++++++++++++++++++++++++

# General styling (matching make_plots_function.R)
font_family <- "Roboto"
color_text_primary <- "grey30"
color_text_secondary <- "grey40"
color_caption_text <- "grey45"
color_grid_lines <- "grey80"

# Plot specific parameters
plot_width_in <- 7
plot_height_in <- 6
plot_dpi <- 300
base_font_size_pt <- 12
title_pt <- 17
subtitle_pt <- 13
axis_title_pt <- 15
axis_text_pt <- 15
caption_pt <- 12
legend_text_pt <- 12

# Colors for the line
color_articles <- "#fa6847" # Using same color as yearly_jul from temperature plots
color_loess <- "#072e6b" # For loess trend
color_smoothed <- "#ff8c00" # For 12-month average

# Line styling
point_size <- 1.2
line_width <- 1.2
smooth_line_width <- 1.4

# Margins
plot_margin_t <- 5
plot_margin_r <- 5
plot_margin_b <- 5
plot_margin_l <- 5

# Convert pt to px for ggtext
title_px_ggtext <- .pt_to_px(title_pt)
subtitle_px_ggtext <- .pt_to_px(subtitle_pt)

# ++++++++++++++++++++++++++++++
# Create Climate Coverage Plot ----
# ++++++++++++++++++++++++++++++

# Add 12-month rolling average for smoother trend
data_with_trend <- data_total %>%
  arrange(date) %>%
  mutate(
    Coverage_12m_avg = zoo::rollmean(
      Coverage,
      k = 12,
      fill = NA,
      align = "right"
    ),
    year = lubridate::year(date)
  )

# Find min/max years for axis scaling
min_year <- min(data_with_trend$year, na.rm = TRUE)
max_year <- max(data_with_trend$year, na.rm = TRUE)

# COP Conference dates (within our data range 2004-2025)
cop_conferences <- tibble(
  cop = c(
    "COP 10",
    "COP 11",
    "COP 12",
    "COP 13",
    "COP 14",
    "COP 15",
    "COP 16",
    "COP 17",
    "COP 18",
    "COP 19",
    "COP 20",
    "COP 21",
    "COP 22",
    "COP 23",
    "COP 24",
    "COP 25",
    "COP 26",
    "COP 27",
    "COP 28",
    "COP 29"
  ),
  date = as.Date(c(
    "2004-12-01",
    "2005-12-01",
    "2006-11-01",
    "2007-12-01",
    "2008-12-01",
    "2009-12-01",
    "2010-11-01",
    "2011-11-01",
    "2012-11-01",
    "2013-11-01",
    "2014-12-01",
    "2015-11-01",
    "2016-11-01",
    "2017-11-01",
    "2018-12-01",
    "2019-12-01",
    "2021-11-01",
    "2022-11-01",
    "2023-11-01",
    "2024-11-01"
  ))
)

# Create the plot
climate_coverage_plot <- ggplot(data_with_trend, aes(x = date)) +
  # Monthly data points
  geom_point(
    aes(y = Coverage, color = "Monatlich"),
    size = point_size,
    alpha = 0.6
  ) +

  # Vertical lines for x-axis breaks
  geom_vline(
    xintercept = as.Date(c(
      "2005-01-01",
      "2010-01-01",
      "2015-01-01",
      "2020-01-01"
    )),
    color = color_grid_lines,
    linewidth = 0.3,
    alpha = 0.7
  ) +

  # Highlight last data point (June 2025)
  geom_point(
    data = data_with_trend %>%
      filter(date == max(date, na.rm = TRUE)),
    aes(x = date, y = Coverage),
    size = point_size * 3.5,
    color = color_articles,
    shape = 1,
    stroke = 1.2
  ) +
  # Highlighted text without halo
  geom_text(
    data = data_with_trend %>%
      filter(date == max(date, na.rm = TRUE)),
    aes(
      x = date - 1260,
      y = min(data_with_trend$Coverage, na.rm = TRUE) +
        (max(data_with_trend$Coverage, na.rm = TRUE) -
          min(data_with_trend$Coverage, na.rm = TRUE)) *
          0.15,
      label = sprintf(
        "Juni '25\n%s Beiträge",
        format(Coverage, big.mark = ".", decimal.mark = ",")
      )
    ),
    vjust = 0.5,
    hjust = 0.3,
    size = 5.8,
    color = color_articles,
    family = font_family,
    fontface = "bold",
    check_overlap = TRUE
  ) +

  # COP Conference markers - positioned at actual coverage values for those months
  geom_point(
    data = cop_conferences %>%
      left_join(
        data_with_trend %>% select(date, Coverage),
        by = "date"
      ) %>%
      filter(!is.na(Coverage)),
    aes(x = date, y = Coverage, color = "COP-Konferenzen"),
    size = 4,
    alpha = 0.3,
    shape = 1,
    stroke = 2
  ) +

  # Annotation lines for specific COP conferences
  geom_segment(
    data = cop_conferences %>%
      left_join(
        data_with_trend %>% select(date, Coverage),
        by = "date"
      ) %>%
      filter(!is.na(Coverage)) %>%
      filter(cop %in% c("COP 15", "COP 26")) %>%
      mutate(
        label_x = case_when(
          cop == "COP 15" ~ date + 500, # Position label to the right
          cop == "COP 26" ~ date - 1100 # Position label to the left
        ),
        label_y = case_when(
          cop == "COP 15" ~ Coverage + 200,
          cop == "COP 26" ~ Coverage + 0
        )
      ),
    aes(x = date, y = Coverage, xend = label_x, yend = label_y),
    color = "grey30",
    linewidth = 0.4,
    alpha = 0.7
  ) +

  # Label for COP 15 (positioned to the right)
  geom_text(
    data = cop_conferences %>%
      left_join(
        data_with_trend %>% select(date, Coverage),
        by = "date"
      ) %>%
      filter(!is.na(Coverage)) %>%
      filter(cop == "COP 15") %>%
      mutate(
        label_x = date + 500,
        label_y = Coverage + 200
      ),
    aes(x = label_x, y = label_y, label = "COP15\nKopenhagen"),
    vjust = 0.5,
    hjust = 0, # left-align
    size = 4.4,
    color = "grey30",
    family = font_family,
    fontface = "bold"
  ) +

  # Label for COP 26 (positioned to the left)
  geom_text(
    data = cop_conferences %>%
      left_join(
        data_with_trend %>% select(date, Coverage),
        by = "date"
      ) %>%
      filter(!is.na(Coverage)) %>%
      filter(cop == "COP 26") %>%
      mutate(
        label_x = date - 1200,
        label_y = Coverage + 150
      ),
    aes(x = label_x, y = label_y, label = "COP26\nGlasgow"),
    vjust = 1,
    hjust = 1, # right-align
    size = 4.4,
    color = "grey30",
    family = font_family,
    fontface = "bold"
  ) +
  geom_smooth(
    aes(y = Coverage, linetype = "Langzeit-Trend"),
    method = "loess",
    formula = y ~ x,
    se = FALSE,
    linewidth = smooth_line_width,
    colour = color_loess,
    span = 0.3
  ) +

  # Color scales
  scale_color_manual(
    name = NULL,
    values = c(
      "Monatlich" = color_articles,
      "COP-Konferenzen" = "black"
    ),
    labels = c(
      "Monatlich" = glue(
        "<span style='color:{color_articles};'>monatliche Werte</span>"
      ),
      "COP-Konferenzen" = "<span style='color:black;'>COP-Konferenzen</span>"
    )
  ) +

  # Linetype scale for trend
  # scale_linetype_manual(
  #     name = "aaa",
  #     values = c("Langzeit-Trend" = "dashed"),
  #     labels = c(
  #         "Langzeit-Trend" = glue(
  #             "<span style='color:{color_loess};'>Langzeit-Trend</span>"
  #         )
  #     )
  # ) +

  # Scales
  scale_y_continuous(
    breaks = scales::pretty_breaks(n = 5),
    labels = scales::number_format(big.mark = ".", decimal.mark = ",")
  ) +
  scale_x_date(
    breaks = as.Date(c(
      "2005-01-01",
      "2010-01-01",
      "2015-01-01",
      "2020-01-01"
    )),
    labels = c("2005", "2010", "2015", "2020"),
    expand = expansion(mult = c(0.02, 0.02))
  ) +

  # Labels
  labs(
    title = glue(
      "<span style='font-weight: 200; font-size:{title_px_ggtext}px; color:{color_text_primary};'><b style='font-family: Roboto-Bold;'>Klimaberichterstattung</b> nimmt wieder ab</span>"
    ),
    subtitle = glue(
      "<span style='font-size:{subtitle_px_ggtext}px; color:{color_text_secondary};'>Anzahl der monatlichen Beiträge in ausgewählten europäischen Tageszeitungen</span>"
    ),
    x = NULL,
    y = glue(
      "<span style='font-size:{.pt_to_px(axis_title_pt)}px; color:{color_text_primary};'>Anzahl Beiträge</span>"
    ),
    caption = glue(
      "<b style='font-family: Roboto-Bold; color:{color_text_primary};'>Methodik:</b> <i style='color:{color_text_secondary};'>Monitoring von 33 europäischen Zeitungen mit Suchbegriffen 'climate change',<br>'global warming', 'Klimawandel', 'cambio climático' über Datenbanken wie Factiva oder NexisUni</i><br>",
      "<b style='font-family: Roboto-Bold; color:{color_text_primary};'>Daten:</b> <i style='color:{color_text_secondary};'>Osborne-Gowey, Jeremiah, et al. European Newspaper Coverage of Climate Change Or<br> Global Warming, 2004-2025 - June 2025</i>"
    )
  ) +

  # Guides
  guides(
    color = guide_legend(
      override.aes = list(
        label = "",
        shape = c(1, 19), # solid circle for monthly, hollow circle for COP
        stroke = c(2, 0), # no stroke for monthly, thick stroke for COP
        size = c(3, 4), # different sizes to match the plot
        alpha = c(.3, .9) # solid for monthly, transparent for COP
      )
    ),
    linetype = guide_legend(override.aes = list(label = ""))
  ) +

  # Theme
  theme_minimal(base_size = base_font_size_pt, base_family = font_family) +
  theme(
    # Backgrounds
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = "transparent", colour = NA),
    legend.key = element_rect(fill = "transparent", colour = NA),

    # Text styling
    plot.title = element_markdown(
      hjust = 0.0,
      margin = margin(b = 10),
      lineheight = 1.1
    ),
    plot.subtitle = element_markdown(
      hjust = 0.0,
      margin = margin(b = -30),
      lineheight = 1.6
    ),

    # Axis styling
    axis.title.x = element_blank(),
    axis.title.y = element_markdown(
      margin = margin(r = 5),
      size = rel(axis_title_pt / base_font_size_pt)
    ),
    axis.text = element_text(
      colour = color_text_secondary,
      size = rel(axis_text_pt / base_font_size_pt)
    ),
    axis.text.x = element_text(margin = margin(t = 2)),
    axis.text.y = element_text(margin = margin(r = 2)),

    # Caption
    plot.caption = element_markdown(
      hjust = 0,
      margin = margin(t = 15),
      size = rel(caption_pt / base_font_size_pt),
      lineheight = 1.3,
      colour = color_caption_text
    ),
    plot.title.position = "plot",
    plot.caption.position = "plot",

    # Legend
    legend.position = "bottom",
    legend.box = "horizontal",
    legend.text = element_markdown(
      size = rel(legend_text_pt / base_font_size_pt)
    ),
    legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
    legend.spacing.x = unit(0.2, "cm"),
    legend.title = element_blank(),

    # Grid
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(
      colour = color_grid_lines,
      linewidth = 0.3
    ),

    # Margins
    plot.margin = margin(
      t = plot_margin_t,
      r = plot_margin_r,
      b = plot_margin_b,
      l = plot_margin_l,
      unit = "pt"
    )
  )

# Display the plot
print(climate_coverage_plot)

# Save the plot
output_dir <- file.path(
  "wiki",
  "climate-analyses",
  "kjn",
  "2025-08-klimaberichterstattung"
)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

plot_filename_png <- file.path(
  output_dir,
  "klimaberichterstattung_entwicklung.png"
)
plot_filename_svg <- file.path(
  output_dir,
  "klimaberichterstattung_entwicklung.svg"
)

# Save as PNG
ggsave(
  filename = plot_filename_png,
  plot = climate_coverage_plot,
  device = png,
  width = plot_width_in,
  height = plot_height_in,
  units = "in",
  dpi = plot_dpi,
  bg = "white"
)

# Save as SVG (using svglite to avoid Cairo dependencies)
ggsave(
  filename = plot_filename_svg,
  plot = climate_coverage_plot,
  device = svglite::svglite,
  width = plot_width_in,
  height = plot_height_in,
  units = "in",
  bg = "white"
)

cli_alert_success(
  "Climate coverage plot saved as PNG: {.path {plot_filename_png}}"
)
cli_alert_success(
  "Climate coverage plot saved as SVG: {.path {plot_filename_svg}}"
)
