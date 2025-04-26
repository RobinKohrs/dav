#' Explore Geosphere Resource Metadata
#'
#' @description
#' Fetches and presents metadata for a specific Geosphere resource ID in a
#' user-friendly format, highlighting available parameters and likely requirements
#' for querying the data endpoint.
#'
#' @param resource_id Character string. The specific resource ID (e.g., "klima-v2-1h"). Required.
#' @param type Character string. The data type (e.g., "grid", "station"). Required. Found via
#'   `geosphere_find_datasets`.
#' @param mode Character string. The data mode (e.g., "historical"). Required. Found via
#'   `geosphere_find_datasets`.
#' @param api_url Base URL for the Geosphere API. Defaults to Geosphere Hub v1.
#' @param version API version string. Defaults to "v1".
#' @param user_agent Client user agent string. Defaults to "davR".
#' @param print_summary Logical. If `TRUE` (default), print a formatted summary
#'   to the console.
#'
#' @return A list containing parsed metadata components:
#'   \item{metadata}{The full metadata list fetched from the API.}
#'   \item{available_parameters}{A data frame (tibble) of available parameters (if found).}
#'   \item{time_coverage}{A list indicating start/end times (if found).}
#'   \item{spatial_info}{A list with spatial details (if found).}
#'   \item{likely_required_query_params}{A character vector suggesting required parameters.}
#'   Returns `NULL` if metadata fetching fails.
#'
#' @export
#' @importFrom httr GET modify_url stop_for_status content http_type user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_h1 cli_h2 cli_li cli_ul cli_text cli_alert_danger cli_alert_warning cli_code style_hyperlink cli_end
#' @importFrom utils head str
#' @importFrom tibble as_tibble
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' # Ensure required packages are installed
#' # install.packages(c("dplyr", "stringr", "tibble", "cli", "httr", "jsonlite"))
#'
#' # 1. Find a dataset first
#'   station_datasets = tryCatch(
#'       geosphere_find_datasets(filter_type="station", filter_mode="historical"),
#'       error = function(e) { print(e$message); NULL }
#'   )
#'
#'   # 2. Explore the chosen dataset (if found)
#'   if(!is.null(station_datasets) && nrow(station_datasets) > 0) {
#'     res_id = station_datasets$resource_id[1]
#'     res_type = station_datasets$type[1]
#'     res_mode = station_datasets$mode[1]
#'
#'     explore_result = tryCatch(
#'         geosphere_explore_resource(
#'              resource_id = res_id,
#'              type = res_type,
#'              mode = res_mode),
#'         error = function(e) { print(e$message); NULL }
#'     )
#'
#'     if (!is.null(explore_result)) {
#'        # A summary was printed (default). You can also inspect the list:
#'        print(str(explore_result, max.level = 1))
#'        print(explore_result$likely_required_query_params)
#'     }
#'   } else {
#'       print("Could not find suitable station datasets to explore.")
#'   }
#'
#' # Explore a grid dataset directly
#'   explore_grid = tryCatch(
#'        geosphere_explore_resource(
#'           resource_id = "apolis_short-v1-1d-100m",
#'           type = "grid",
#'           mode = "historical"),
#'        error = function(e) { print(e$message); NULL }
#'    )
#' }
geosphere_explore_resource = function(resource_id,
                                      type,
                                      mode,
                                      api_url = "https://dataset.api.hub.geosphere.at",
                                      version = "v1",
                                      user_agent = "davR",
                                      print_summary = TRUE) {

  # --- Basic Input Checks ---
  if (missing(resource_id) || !nzchar(trimws(resource_id))) stop("`resource_id` must be provided.", call.=FALSE)
  if (missing(type) || !nzchar(trimws(type))) stop("`type` must be provided.", call.=FALSE)
  if (missing(mode) || !nzchar(trimws(mode))) stop("`mode` must be provided.", call.=FALSE)

  # --- 1. Fetch Metadata ---
  # Use the previously defined function which handles its own errors/NULL return
  metadata = geosphere_get_params_metadata(
    resource_id = resource_id,
    type = type,
    mode = mode,
    api_url = api_url,
    version = version,
    user_agent = user_agent
  )

  if (is.null(metadata)) {
    # geosphere_get_params_metadata already prints alerts on failure
    cli::cli_alert_warning("Cannot proceed with exploration for resource {.val {resource_id}}.")
    return(NULL)
  }

  # --- 2. Parse and Structure Metadata Components ---
  output = list(
    metadata = metadata,
    available_parameters = NULL,
    time_coverage = NULL,
    spatial_info = NULL,
    likely_required_query_params = character(0)
  )

  # Extract Available Parameters
  if (!is.null(metadata$parameters)) {
    if (is.data.frame(metadata$parameters)) {
      # Ensure it's a tibble for nice printing
      output$available_parameters = tibble::as_tibble(metadata$parameters)
    } else if (is.list(metadata$parameters) && length(metadata$parameters) > 0) {
      # Attempt to bind if it's a list of lists/vectors
      param_df = tryCatch(
        dplyr::bind_rows(metadata$parameters),
        error = function(e) {
          warning("Could not automatically bind 'parameters' list into a data frame.", call. = FALSE)
          NULL
        }
      )
      if (!is.null(param_df)) {
        output$available_parameters = tibble::as_tibble(param_df)
      }
    }
  }

  # Extract Time Coverage
  time_info = list()
  if (!is.null(metadata$start_time)) time_info$start_time = metadata$start_time
  if (!is.null(metadata$end_time)) time_info$end_time = metadata$end_time
  if (!is.null(metadata$timerange)) time_info$timerange = metadata$timerange
  if (length(time_info) > 0) output$time_coverage = time_info

  # Extract Spatial Info
  spatial = list()
  if (!is.null(metadata$crs)) spatial$crs = metadata$crs
  if (!is.null(metadata$bbox)) spatial$bbox = metadata$bbox
  if (!is.null(metadata$spatial_resolution_m)) spatial$resolution_m = metadata$spatial_resolution_m
  if (!is.null(metadata$grid_bounds)) spatial$grid_bounds = metadata$grid_bounds
  if (length(spatial) > 0) output$spatial_info = spatial

  # --- 3. Infer Likely Required Query Parameters ---
  # Start with base requirements (can be refined)
  req = c("parameters", "start", "end")

  # Adjust based on type
  if (type == "grid") {
    # Grids usually need bbox or sometimes lat/lon for point extraction
    # If metadata has bbox, it's likely the main requirement
    if (!is.null(output$spatial_info$bbox) || !is.null(output$spatial_info$grid_bounds)) {
      req = c(req, "bbox") # Add bbox as likely needed
    } else {
      # If no obvious grid bounds, maybe point extraction? Less common for this API
      req = c(req, "lat", "lon") # Less likely, but possible fallback
    }
  } else if (type == "station") {
    # Only require station_ids if stations are actually listed in metadata
    if (!is.null(metadata$stations) && length(metadata$stations) > 0) {
      req = c(req, "station_ids")
    }
  }

  # Refine based on metadata specifics
  # If metadata indicates no time dimension, remove start/end
  if (length(time_info) == 0 && is.null(metadata$timeCoverage)) {
    req = setdiff(req, c("start", "end"))
  }
  # If only one parameter is available, 'parameters' is likely still required by API
  if (is.null(output$available_parameters) || nrow(output$available_parameters) == 0) {
    req = setdiff(req, "parameters") # No parameters to choose from
  }

  # Check for explicit requirements field (less common in this API)
  required_explicit = NULL
  if (!is.null(metadata$required_parameters) && is.character(metadata$required_parameters)) {
    required_explicit = metadata$required_parameters
  } else if (!is.null(metadata$queryParameters)) {
    if (is.data.frame(metadata$queryParameters) && "name" %in% names(metadata$queryParameters) && "required" %in% names(metadata$queryParameters)) {
      req_df = metadata$queryParameters
      required_explicit = req_df$name[req_df$required == TRUE]
    }
  }
  if (!is.null(required_explicit)) {
    req = unique(c(req, required_explicit)) # Ensure explicit ones are included
  }


  output$likely_required_query_params = unique(req) # Store the unique list

  # --- 4. Print Summary (Optional) ---
  if (print_summary) {
    cli::cli_h1("Metadata Summary for Resource: {.val {resource_id}}")
    cli::cli_text("Type: {.val {type}}, Mode: {.val {mode}}")
    if (!is.null(metadata$title)) cli::cli_text("Title: {.val {metadata$title}}")

    # Construct URLs safely
    url_path_part = tryCatch(paste(version, type, mode, resource_id, sep = "/"), error = function(e) NULL)
    if(!is.null(url_path_part)) {
      data_url = httr::modify_url(api_url, path = url_path_part)
      meta_url = paste0(data_url,"/metadata")
      cli::cli_text("Data URL: {.url {data_url}}")
      cli::cli_text("Metadata URL: {.url {meta_url}}")
    }

    cli::cli_h2("Available Parameters")
    if (!is.null(output$available_parameters) && nrow(output$available_parameters) > 0) {
      # Select common columns for printing, if they exist
      cols_to_print = intersect(c("name", "long_name", "unit", "desc"), names(output$available_parameters))
      if(length(cols_to_print) > 0) {
        print(utils::head(output$available_parameters[, cols_to_print, drop = FALSE]))
      } else {
        print(utils::head(output$available_parameters)) # Print whatever columns exist
      }
      if(nrow(output$available_parameters) > 6) cli::cli_text("({nrow(output$available_parameters) - 6} more parameters available...)")
    } else {
      cli::cli_text("No specific parameter list found or parsed from metadata.")
    }

    cli::cli_h2("Time Coverage")
    if (!is.null(output$time_coverage)) {
      cli::cli_ul()
      if (!is.null(output$time_coverage$start_time)) cli::cli_li("Start: {.val {output$time_coverage$start_time}}")
      if (!is.null(output$time_coverage$end_time)) cli::cli_li("End: {.val {output$time_coverage$end_time}}")
      if (!is.null(output$time_coverage$timerange)) cli::cli_li("Timerange field: {.val {paste(output$time_coverage$timerange, collapse=', ')}}")
      cli::cli_end()
    } else {
      cli::cli_text("No specific time coverage information found.")
    }

    cli::cli_h2("Spatial Information")
    if (!is.null(output$spatial_info)) {
      cli::cli_ul()
      if (!is.null(output$spatial_info$crs)) cli::cli_li("CRS: {.val {output$spatial_info$crs}}")
      if (!is.null(output$spatial_info$bbox)) cli::cli_li("Bounding Box (Native CRS): {.val {paste(round(output$spatial_info$bbox, 4), collapse=', ')}}")
      if (!is.null(output$spatial_info$resolution_m)) cli::cli_li("Resolution (meters): {.val {output$spatial_info$resolution_m}}")
      if (!is.null(output$spatial_info$grid_bounds)) cli::cli_li("Grid Bounds (Native CRS): {.val {paste(output$spatial_info$grid_bounds, collapse=', ')}}")
      cli::cli_end()
    } else {
      cli::cli_text("No specific spatial information found.")
    }

    cli::cli_h2("Likely Required Query Parameters for {.fn geosphere_get_data}")
    if (length(output$likely_required_query_params) > 0) {
      cli::cli_ul()
      for(p in output$likely_required_query_params) cli::cli_li("{.code {p}}")
      cli::cli_end()
      cli::cli_text("Note: This is inferred from metadata. Use {.fn geosphere_get_data} with ",
                    "{.code check_metadata=TRUE} for validation before requesting data.")
    } else {
      cli::cli_text("Could not determine likely required parameters (or none seem required based on metadata).")
    }
    cli::cli_h1("End Metadata Summary") # Visual separator
  }

  # --- 5. Return Structured List ---
  return(output)
}
