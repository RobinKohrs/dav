# build a stop × route table for vienna public transport from wiener linien gtfs
##
## output: one row per unique stop × route combination, with columns:
##   stop_id, stop_name, stop_lat, stop_lon,
##   route_short_name, route_type, route_color
##
## gtfs join chain: stops → stop_times → trips → routes
## stop_times.txt is large (~3m rows); uses readr + dplyr for efficiency.

library(readr)
library(dplyr)

base_url <- "https://www.wienerlinien.at/ogd_realtime/doku/ogd/gtfs"

message("downloading gtfs files...")
stops      <- read_csv(file.path(base_url, "stops.txt"),      show_col_types = false)
routes     <- read_csv(file.path(base_url, "routes.txt"),     show_col_types = false)
trips      <- read_csv(file.path(base_url, "trips.txt"),      show_col_types = false)
stop_times <- read_csv(file.path(base_url, "stop_times.txt"), show_col_types = false)

message("building stop × route table...")

stop_routes <- stop_times |>
  # only keep the columns we need before the join (keeps memory low)
  distinct(trip_id, stop_id) |>
  left_join(trips  |> distinct(trip_id, route_id),          by = "trip_id") |>
  left_join(routes |> select(route_id, route_short_name, route_type, route_color),
    by = "route_id") |>
  distinct(stop_id, route_short_name, route_type, route_color) |>
  left_join(stops |> select(stop_id, stop_name, stop_lat, stop_lon),
    by = "stop_id") |>
  select(stop_id, stop_name, stop_lat, stop_lon,
    route_short_name, route_type, route_color) |>
  arrange(stop_name, route_short_name)

message(sprintf("done: %d stop × route combinations across %d unique stops.",
  nrow(stop_routes),
  n_distinct(stop_routes$stop_id)))

write_csv(stop_routes, here::here("data", "csv", "wien_gtfs_stop_routes.csv"))
message("saved to data/csv/wien_gtfs_stop_routes.csv")



jj
