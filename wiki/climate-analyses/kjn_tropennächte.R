# --------------------------------------------------------------------------
# Title: Temperaturen in der Nacht (Night Temperatures)
# Author: Robin Kohrs / Netzwerk Klimajournalismus
# Date: YYYY-MM-DD (R Script Conversion)
# Description: This script analyzes hourly temperature data to determine
#              night temperature trends, focusing on July.
#              It can download data for a single station (Wien Hohe Warte)
#              or all capital city stations in Austria.
#              Data for June, July, and August is downloaded in a single block
#              per year, then filtered for July for the final analysis.
#              Paths are defined using here::here() and davR::sys_make_path.
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# I. SCRIPT CONFIGURATION
# --------------------------------------------------------------------------
# Set to TRUE to download data for all capital city stations.
# Set to FALSE (default) to download data only for station 105 (Wien Hohe Warte).
download_all_stations =  TRUE# <<< USER PARAMETER

# --------------------------------------------------------------------------
# II. LOAD LIBRARIES
# --------------------------------------------------------------------------
# Note: Ensure these libraries are installed before running the script.
# You can install them using:
# install.packages(c("tidyverse", "glue", "davR", "here", "sf", "ggtext", "zoo", "lubridate", "data.table", "cli"))

library(tidyverse)    # For data manipulation (dplyr, ggplot2, etc.) and pipes (%>%)
library(glue)         # For easy string interpolation
library(davR)         # For geosphere data access AND sys_make_path
library(here)         # For robust path construction relative to project root
library(sf)           # For spatial data operations (used for st_drop_geometry)
library(ggtext)       # For markdown/HTML in ggplot2 text (e.g., titles)
library(zoo)          # For rolling mean calculation (rollmean)
library(lubridate)    # For date-time manipulation (month, year, hour, days_in_month)
library(data.table)   # For fast file reading (fread)
library(cli)          # For styled command-line messages

# --------------------------------------------------------------------------
# III. DEFINE PATHS AND GLOBAL VARIABLES
# --------------------------------------------------------------------------

# --- Define base paths using here::here() ---
# Assumes your R session's working directory is the project root,
# or that 'here' can correctly identify the project root.

# Path for raw hourly data. davR::sys_make_path creates the directory if it doesn't exist.
# Example: [ProjectRoot]/data_raw/tropennächte_studie/stationenStundenDaten/
data_raw_base_for_script = here::here(sys_get_script_dir(), "data_raw")
data_raw_path_hourly_data = davR::sys_make_path(file.path(data_raw_base_for_script, "stationenStundenDaten_raw"))
data_raw_path_hourly_data_processed = davR::sys_make_path(file.path(data_raw_base_for_script, "processed/tropennächte/dw"))
data_raw_path_hourly_data_invalid = davR::sys_make_path(file.path(data_raw_base_for_script, "processed/tropennächte/invalid"))


# Path for saving output images
# Example: [ProjectRoot]/images_r_output/
output_images_path = davR::sys_make_path(file.path(sys_get_script_dir(), "images/tropennächte"))


# Data download parameters
resource_id = "klima-v2-1h"
start_year = 1940   # Earliest year to attempt download for
end_year = 2025     # Latest year to attempt download for (adjust if needed)

# Target month for analysis
month_start = 6
month_end = 8

# Night hours definition
night_hours_filter_expression = quote(hour(time) >= 22 | hour(time) <= 6)

# --------------------------------------------------------------------------
# IV. DATA DOWNLOAD (June-August block download per year)
# --------------------------------------------------------------------------
cli::cli_alert_info("Starting data download process...")
stations = davR::geosphere_get_stations()
station_ids = stations$id


if (!download_all_stations) {
  station_ids = c(105) # wien hohe warte
}

for (station_id in station_ids) {

  ##### get the name of the station
  station_name_real = stations %>%
    filter(id == station_id) %>%
    pull(name)

  station_clean_name <- stations %>%
    filter(id == station_id) %>%
    pull(name) %>%
    janitor::make_clean_names()

  ###### download the data
  for (current_year in start_year:end_year) {
    start_date_period <- glue::glue("{current_year}-{month_start}-01")
    end_date_period <- glue::glue("{current_year}-{month_end}-31")


    filename = glue::glue("{station_clean_name}__id{station_id}__ys{current_year}__ye{current_year}__ms{month_start}__me{month_end}__hourly_data.csv")
    output_filepath <- sys_make_path(file.path(data_raw_path_hourly_data, station_id, filename))
    # create the dirs
    sys_make_path(output_filepath)

    if (file.exists(output_filepath)) {
      cli::cli_alert_info(paste0("File already exists, skipping download: ", filename))
    } else {
      cli::cli_alert_info(glue::glue("Attempting to download data for: Year {current_year}, Period June-August"))
      download_attempt <- tryCatch(
        {
          davR::geosphere_get_data(
            resource_id = resource_id,
            parameters = c("tl"),
            start = start_date_period,
            end = end_date_period,
            station_ids = station_id,
            type = "station",
            mode = "historical",
            output_file = output_filepath,
            timeout_seconds = 10
          )
          TRUE
        },
        error = function(e) {
          cli::cli_warn(glue::glue("Failed downloading data for {current_year} (June-August) for stations '{paste(station_id)}': {conditionMessage(e)}"))
          return(NULL)
        }
      )
      if (isTRUE(download_attempt)) {
        cli::cli_alert_success(glue::glue("Successfully downloaded and saved: {filename}"))
      }
    }
  }

  # load all data  ------------------------------------------------------
  cli::cli_alert_info("Loading and preprocessing downloaded data...")

  data_files_paths = list.files(
    path = data_raw_path_hourly_data,
    pattern = glue("id{station_id}_.*\\.csv"),
    full.names = TRUE
  )

  if (length(data_files_paths) == 0) {
    cli::cli_abort(
      glue::glue(
        "No files found"
      )
    )
  }

  all_downloaded_data = purrr::map_dfr(data_files_paths, function(filepath) {
    tryCatch(
      {
        suppressMessages(read_csv(filepath))
      },
      error = function(e) {
        cli::cli_warn(glue::glue("Error reading file {filepath}: {conditionMessage(e)}"))
        return(NULL)
      }
    )
  })


  # calculate means for each month  --------------------------------------------
  mean_data = all_downloaded_data %>%
    mutate(
      year = year(time),
      month = month(time),
      hour = hour(time)
    ) %>%
    filter(hour >= 22 | hour < 6) %>%
    # 3. Group by year and month
    group_by(year, month) %>%
    # 4. Calculate the mean nightly temperature, ignoring NAs
    summarise(
      mean_nightly_tl = mean(tl, na.rm = TRUE),
      valid_hours = sum(!is.na(tl)),
      nonvalid_hours = sum(is.na(tl)),
      share_invalid = nonvalid_hours / (valid_hours + nonvalid_hours),
      .groups = 'drop'
    ) %>%
    filter(!is.nan(mean_nightly_tl)) %>%
    # 5. Order the results (optional, but nice)
    arrange(year, month)

  # check for each year if the share of non valid data is higher than 5 percent
  df_invalid_high_share = mean_data %>% filter(share_invalid >= 0.05)
  if (nrow(df_invalid_high_share) > 0) {
    cli::cli_warn(
      glue(
        "For: {station_clean_name} there are years with a invalid data share of larger than 5 %"
      )
    )
    filename = glue("id{station_id}_HIGH_SHARE_NAs.csv")
    op_invalid = file.path(data_raw_path_hourly_data_invalid, filename)
    write_csv(df_invalid_high_share, op_invalid)
  }

 #  prepare for datawrapper format  ------------------------------------------------------
  data_dw <- mean_data %>%
    select(year, month, mean_nightly_tl) %>%
    mutate(
      month = lubridate::month(month, label = T)
    ) %>%
    pivot_wider(
      names_from = month,
      values_from = mean_nightly_tl
    ) %>%
    mutate(
      across(
        .cols = c(Jun, Jul, Aug), # Columns to apply the function to
        .fns = ~ rollapply(.x, # .x refers to the current column's data
          width = 5,
          FUN = mean,
          align = "right",
          fill = NA,
          na.rm = TRUE
        ),
        .names = "{.col}_5yr_avg" # Naming convention for the new columns
      )
    ) %>%
    mutate(
      station_id = station_id,
      .before = 1,
    ) %>%
    mutate(
      station_name = station_name_real,
      .before = 1
    )

  # write out  ------------------------------------------------------
  min_start_year = min(data_dw$year)
  max_start_year = max(data_dw$year)
  filename_dw = glue::glue("{station_clean_name}__id{station_id}__ys{min_start_year}__ye{max_start_year}__ms{month_start}__me{month_end}__meanNightTempPerMonth.csv")
  op_dw = file.path(data_raw_path_hourly_data_processed, filename_dw)
  write_csv(data_dw, op_dw)
}

# --------------------------------------------------------------------------
# VI. ANALYSIS AND PLOT FOR WIEN HOHE WARTE (Station 105)
# --------------------------------------------------------------------------

data_station105_july = master_july_data %>%
  dplyr::filter(station == 105)

if (nrow(data_station105_july) == 0) {
  cli::cli_warn("No data for station 105 found in the loaded July data. Skipping Wien Hohe Warte analysis.")
} else {
  data_per_year_station105 = data_station105_july %>%
    dplyr::filter(!!night_hours_filter_expression) %>%
    dplyr::group_by(year = lubridate::year(time)) %>%
    dplyr::summarise(mean_night_temp_july = mean(tl, na.rm = TRUE), .groups = "drop") %>%
    dplyr::arrange(year) %>%
    dplyr::mutate(smoothed_5yr_mean = zoo::rollmean(
      x = mean_night_temp_july, k = 5, fill = NA, align = "right"
    ))

  color_yearly_wien = "tomato"
  color_smoothed_wien = "#343434"

  smoothed_means_long_wien = data_per_year_station105 %>%
    tidyr::pivot_longer(
      cols = c(mean_night_temp_july, smoothed_5yr_mean),
      names_to = "average_type",
      values_to = "temperature"
    ) %>%
    dplyr::mutate(average_type = factor(average_type,
                                        levels = c("mean_night_temp_july", "smoothed_5yr_mean"),
                                        labels = c("Jährlich", "5-Jahres Glättung")))

  min_plot_start_year_wien = smoothed_means_long_wien %>%
    dplyr::filter(average_type == "5-Jahres Glättung" & !is.na(temperature)) %>%
    dplyr::pull(year) %>%
    min(na.rm = TRUE)

  if (!is.finite(min_plot_start_year_wien)) {
    cli::cli_warn("Could not find a starting year with non-NA smoothed data for Wien plot. Using overall minimum year.")
    min_plot_start_year_wien = min(smoothed_means_long_wien$year, na.rm = TRUE)
  }

  plot_wien = ggplot2::ggplot(smoothed_means_long_wien, ggplot2::aes(x = year, y = temperature, color = average_type)) +
    ggplot2::geom_point(data = . %>% dplyr::filter(average_type == "Jährlich"), size = 2, alpha = 0.7) +
    ggplot2::geom_line(data = . %>% dplyr::filter(average_type == "5-Jahres Glättung"), linewidth = 1.2) +
    ggplot2::geom_hline(yintercept = 20, linetype = "dashed", color = "darkgrey", linewidth = 0.8) +
    ggplot2::annotate(geom = "text",
                      x = Inf, y = 20.1,
                      label = "Tropennacht (>= 20°C)",
                      hjust = 1.05, vjust = 0, color = "darkgrey", size = 3.5) +
    ggplot2::scale_color_manual(
      name = "Mittelwerttyp",
      values = c("Jährlich" = color_yearly_wien, "5-Jahres Glättung" = color_smoothed_wien)
    ) +
    ggplot2::coord_cartesian(xlim = c(if(is.finite(min_plot_start_year_wien)) min_plot_start_year_wien - 0.5 else NA, NA), clip = "off") +
    ggplot2::labs(
      title = glue::glue(
        "Juli Nachttemperatur (Wien Hohe Warte): <span style='color:{color_yearly_wien};'>Jährlich</span> vs <span style='color:{color_smoothed_wien};'>5-Jahres Glättung</span>"
      ),
      subtitle = "Nacht definiert als 22:00 - 06:59 Uhr | Station Wien Hohe Warte (ID 105)",
      x = "Jahr",
      y = "Mittlere Temperatur (°C)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title = ggtext::element_markdown(hjust = 0.5, size = 14),
      plot.subtitle = ggplot2::element_text(hjust = 0.5),
      plot.background = ggplot2::element_rect(fill = "#e1edf7", colour = "transparent"),
      plot.margin = ggplot2::margin(t = 15, r = 5.5, b = 5.5, l = 5.5, unit = "pt"),
      panel.grid = ggplot2::element_line(color = "#35353599", linewidth = 0.05)
    )

  print(plot_wien)

  output_plot_filename_wien = "wien_hohe_warte_july_night_temps.png"
  output_plot_filepath_wien = file.path(output_images_path, output_plot_filename_wien)
  ggplot2::ggsave(output_plot_filepath_wien, plot = plot_wien, width = 10, height = 7, dpi = 300)
  cli::cli_alert_success(paste0("Plot for Wien Hohe Warte saved to: ", output_plot_filepath_wien))
}

# --------------------------------------------------------------------------
# VII. ANALYSIS AND PLOT FOR ALL CAPITAL STATIONS (if data was downloaded)
# --------------------------------------------------------------------------
if (download_all_stations) {
  cli::cli_alert_info("Starting analysis for all capital city stations...")

  if (!exists("geosphere_stations_in_capitals", where = asNamespace("davR"))) {
    cli::cli_abort("Object {.var geosphere_stations_in_capitals} not found in {.pkg davR} for all stations analysis.")
  }

  data_per_year_capitals = master_july_data %>%
    dplyr::filter(!!night_hours_filter_expression) %>%
    dplyr::group_by(year = lubridate::year(time), station) %>%
    dplyr::summarise(mean_night_temp_july = mean(tl, na.rm = TRUE), .groups = "drop") %>%
    dplyr::left_join(davR::geosphere_stations_in_capitals %>% dplyr::select(id, name) %>% sf::st_drop_geometry(),
                     by = c("station" = "id")) %>%
    dplyr::group_by(name) %>%
    dplyr::arrange(year, .by_group = TRUE) %>%
    dplyr::mutate(smoothed_5yr_mean = zoo::rollmean(
      x = mean_night_temp_july, k = 5, fill = NA, align = "right"
    )) %>%
    dplyr::ungroup() %>%
    dplyr::select(-station)

  if (nrow(data_per_year_capitals) == 0) {
    cli::cli_warn("No data processed for capital stations. Skipping faceted plot.")
  } else {
    color_yearly_capitals = "tomato"
    color_smoothed_capitals = "#343434"
    color_loess_capitals = "black"

    smoothed_means_long_capitals = data_per_year_capitals %>%
      tidyr::pivot_longer(
        cols = c(mean_night_temp_july, smoothed_5yr_mean),
        names_to = "average_type",
        values_to = "temperature"
      ) %>%
      dplyr::mutate(average_type = factor(average_type,
                                          levels = c("mean_night_temp_july", "smoothed_5yr_mean"),
                                          labels = c("Jährlich", "5-Jahres Glättung")))

    min_plot_start_year_capitals = smoothed_means_long_capitals %>%
      dplyr::filter(average_type == "5-Jahres Glättung" & !is.na(temperature)) %>%
      dplyr::pull(year) %>%
      min(na.rm = TRUE)

    if (!is.finite(min_plot_start_year_capitals)) {
      cli::cli_warn("Could not find a starting year with non-NA smoothed data for capitals plot.")
      min_plot_start_year_capitals = min(smoothed_means_long_capitals$year, na.rm = TRUE)
      if (!is.finite(min_plot_start_year_capitals)) min_plot_start_year_capitals = start_year_download
    }

    plot_capitals = ggplot2::ggplot(smoothed_means_long_capitals, ggplot2::aes(x = year, y = temperature)) +
      ggplot2::geom_point(data = . %>% dplyr::filter(average_type == "Jährlich"),
                          ggplot2::aes(color = average_type),
                          size = 1, alpha = 0.7, key_glyph = "point") +
      ggplot2::geom_smooth(
        data = . %>% dplyr::filter(average_type == "Jährlich"),
        method = "loess", linewidth = 0.5, colour = color_loess_capitals, se = FALSE,
        ggplot2::aes(linetype = "Loess Glättung"), key_glyph = "timeseries"
      ) +
      ggplot2::geom_hline(yintercept = 20, linetype = "dashed", color = "darkgrey", linewidth = 0.5) +
      ggplot2::annotate(geom = "text", x = if(is.finite(min_plot_start_year_capitals)) min_plot_start_year_capitals + 5 else 1950, y = 20.1, # Adjusted x for better placement
                        label = "Tropennacht (>= 20°C)",
                        hjust = 0, vjust = -0.5, color = "#353535", size = 1.8) +
      ggplot2::scale_color_manual(
        name = NULL,
        values = c("Jährlich" = color_yearly_capitals, "5-Jahres Glättung" = color_smoothed_capitals),
        guide = ggplot2::guide_legend(override.aes = list(shape = c(16, NA)[seq_along(levels(smoothed_means_long_capitals$average_type))]))
      ) +
      ggplot2::scale_linetype_manual(name = NULL, values = c("Loess Glättung" = "solid")) +
      ggplot2::coord_cartesian(xlim = c(if(is.finite(min_plot_start_year_capitals)) min_plot_start_year_capitals - 0.5 else NA, NA), clip = "off") +
      ggplot2::labs(
        title = glue::glue(
          "Juli Nachttemperatur (Hauptstädte): <span style='color:{color_yearly_capitals};'>Jährlich</span> vs <span style='color:{color_loess_capitals};'>Loess Glättung</span>"
        ),
        subtitle = "Nacht definiert als 22:00 - 06:59 Uhr",
        x = "Jahr",
        y = "Mittlere Temperatur (°C)"
      ) +
      ggplot2::facet_wrap(~name, scales = "free_y") +
      ggplot2::theme_minimal(base_size = 8) +
      ggplot2::theme(
        legend.position = "bottom",
        plot.title = ggtext::element_markdown(hjust = 0.5, size = 14),
        plot.subtitle = ggplot2::element_text(hjust = 0.5),
        strip.background = ggplot2::element_rect(fill = "transparent", color = NA),
        strip.text = ggplot2::element_text(face = "bold", size=7),
        panel.grid = ggplot2::element_line(color = "#35353599", linewidth = 0.05),
        panel.border = ggplot2::element_rect(fill = "transparent", colour = "#353535"),
        plot.margin = ggplot2::margin(t = 15, r = 5.5, b = 5.5, l = 5.5, unit = "pt"),
        plot.background = ggplot2::element_rect(fill = "#ffffff", colour = "transparent")
      )

    print(plot_capitals)

    output_plot_filename_capitals = "all_capitals_july_night_temps.png"
    output_plot_filepath_capitals = file.path(output_images_path, output_plot_filename_capitals)
    ggplot2::ggsave(output_plot_filepath_capitals, plot = plot_capitals, width = 12, height = 9, dpi = 300)
    cli::cli_alert_success(paste0("Faceted plot for capital cities saved to: ", output_plot_filepath_capitals))
  }
} else {
  cli::cli_alert_info("Skipping analysis for all capital stations as 'download_all_stations' is FALSE.")
}

cli::cli_alert_success("Script finished successfully.")
# End of R Script
