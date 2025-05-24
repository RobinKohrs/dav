#' Download ACLED Data Interactively or Programmatically (Manual URL Construction)
#'
#' This function calls the official ACLED API directly to download
#' data for user-specified event types, sub-event types, and geographic areas.
#' It uses manual construction of the URL query string.
#' It can operate interactively for selecting event types and sub-event types.
#' It handles API pagination to retrieve all relevant data.
#'
#' Authentication credentials (email and access key) can be provided as arguments
#' or retrieved from environment variables `ACLED_EMAIL` and `ACLED_API_KEY`.
#'
#' @param email_address Your registered ACLED API email address.
#'                      If `NULL` or missing, uses `ACLED_EMAIL` env var.
#' @param access_key Your ACLED API access key.
#'                   If `NULL` or missing, uses `ACLED_API_KEY` env var.
#' @param start_date Character string or Date object. Start date (YYYY-MM-DD). Required.
#' @param end_date Character string or Date object. End date (YYYY-MM-DD). Required.
#' @param country Character vector. Optional. ACLED country name(s).
#'                Example: `c("Yemen", "Syria")`.
#' @param region Character or numeric vector. Optional. ACLED region name(s) or code(s).
#'               See ACLED API documentation or `acled.api::get.api.regions()`.
#' @param admin1 Character vector. Optional. First-level administrative region(s).
#' @param admin2 Character vector. Optional. Second-level administrative region(s).
#' @param admin3 Character vector. Optional. Third-level administrative region(s).
#' @param event_types Character vector. Optional. ACLED event type(s).
#'                    If `NULL` and `interactive_events = FALSE`, all event types considered.
#'                    If `interactive_events = TRUE`, this argument is ignored initially.
#'                    Example: `c("Battles", "Explosions/Remote violence")`.
#' @param sub_event_types Character vector. Optional. ACLED sub-event type(s).
#'                        If `NULL`, all sub-types for selected `event_types` considered.
#'                        If `interactive_events = TRUE`, this argument is ignored initially.
#'                        Example: `c("Air/drone strike", "Armed clash")`.
#' @param interactive_events Logical. If `TRUE`, prompts user to select event types
#'                           and sub-event types. Defaults to `FALSE`.
#' @param page_limit Numeric. Records per API page request.
#' @param max_pages Numeric. Maximum pages to fetch to prevent overly long requests.
#' @param output_format Character. "df" for a data.frame or "raw_json" for raw list.
#' @param ... Additional query parameters to pass directly to the ACLED API
#'            as a named list (e.g., `list(terms_of_use="yes", source="Reuters")`).
#'            These will be added to the manually constructed URL string.
#'            See ACLED API guide for available parameters.
#'
#' @return A data.frame containing the queried ACLED event data (if `output_format = "df"`),
#'         or a list of parsed JSON content from each page (if `output_format = "raw_json"`).
#'         Returns NULL if a critical error occurs or no data is found.
#' @export
#' @importFrom httr GET content http_type http_error status_code user_agent
#' @importFrom jsonlite fromJSON
#' @importFrom utils URLencode read.csv select.list menu
#' @importFrom cli cli_abort cli_alert_info cli_alert_success cli_alert_warning cli_alert_danger cli_process_start cli_process_done cli_process_failed cli_bullets cli_h1 cli_progress_bar cli_progress_update cli_progress_done cli_text cli_format_inline cli_ask
#' @examples
#' \dontrun{
#' # --- Set environment variables first (recommended) ---
#' # Sys.setenv(ACLED_EMAIL = "YOUR_EMAIL")
#' # Sys.setenv(ACLED_API_KEY = "YOUR_ACCESS_KEY")
#'
#' # Example 1: Explosions in Yemen for a specific period
#' yemen_explosions = acled_download_events(
#'   start_date = "2023-01-01",
#'   end_date = "2023-01-31",
#'   country = "Yemen",
#'   event_types = "Explosions/Remote violence"
#' )
#' if (!is.null(yemen_explosions) && nrow(yemen_explosions) > 0) {
#'   print(head(yemen_explosions[, c("event_date", "country", "admin1", "event_type")]))
#' }
#' }
acled_download_events = function(email_address = NULL,
                                 access_key = NULL,
                                 start_date,
                                 end_date,
                                 country = NULL,
                                 region = NULL,
                                 admin1 = NULL,
                                 admin2 = NULL,
                                 admin3 = NULL,
                                 event_types = NULL,
                                 sub_event_types = NULL,
                                 interactive_events = FALSE,
                                 page_limit = 5000,
                                 max_pages = 100,
                                 output_format = "df",
                                 ...) {

  # --- Package Checks ---
  if (!requireNamespace("httr", quietly = TRUE)) cli::cli_abort("Package {.pkg httr} is required.")
  if (!requireNamespace("jsonlite", quietly = TRUE) && output_format != "csv") cli::cli_abort("Package {.pkg jsonlite} is required for JSON parsing.")
  if (!requireNamespace("cli", quietly = TRUE)) stop("Package 'cli' is required.")


  # --- ACLED Event Taxonomy ---
  acled_event_taxonomy = list(
    "Battles" = list(sub_event_types = c("Government regains territory", "Non-state actor overtakes territory", "Armed clash")),
    "Protests" = list(sub_event_types = c("Excessive force against protesters", "Protest with intervention", "Peaceful protest")),
    "Riots" = list(sub_event_types = c("Violent demonstration", "Mob violence")),
    "Explosions/Remote violence" = list(sub_event_types = c("Chemical weapon", "Air/drone strike", "Suicide bomb", "Shelling/artillery/missile attack", "Remote explosive/landmine/IED", "Grenade")),
    "Violence against civilians" = list(sub_event_types = c("Sexual violence", "Attack", "Abduction/forced disappearance")),
    "Strategic developments" = list(sub_event_types = c("Agreement", "Arrests", "Change to group/activity", "Disrupted weapons use", "Headquarters or base established", "Looting/property destruction", "Non-violent transfer of territory", "Other"))
  )
  all_main_event_types = names(acled_event_taxonomy)

  # --- Credential Handling ---
  used_env_email = FALSE
  if (is.null(email_address) || nchar(email_address) == 0) {
    email_address = Sys.getenv("ACLED_EMAIL")
    if (nchar(email_address) == 0) cli::cli_abort(c("ACLED API email address not found.", "x" = "Provide via {.arg email_address} or set {.envvar ACLED_EMAIL}."))
    used_env_email = TRUE
  }
  used_env_key = FALSE
  if (is.null(access_key) || nchar(access_key) == 0) {
    access_key = Sys.getenv("ACLED_API_KEY")
    if (nchar(access_key) == 0) cli::cli_abort(c("ACLED API access key not found.", "x" = "Provide via {.arg access_key} or set {.envvar ACLED_API_KEY}."))
    used_env_key = TRUE
  }

  # --- Validate required date arguments ---
  if (missing(start_date) || missing(end_date)) cli::cli_abort("{.arg start_date} and {.arg end_date} are required arguments.")

  # --- Interactive Event Selection ---
  selected_event_types_api = event_types
  selected_sub_event_types_api = sub_event_types
  if (interactive_events) {
    if (!interactive()) {
      cli::cli_alert_warning("{.arg interactive_events} is TRUE, but session not interactive. Using provided/default event types.")
      if(is.null(event_types)) cli::cli_alert_info("No event_types specified, will query all for selected geography.")
    } else {
      cli::cli_h1("Interactive Event Selection")
      cli::cli_alert_info("Select one or more main event types.")
      cli::cli_text("Use numbers separated by spaces (e.g., 1 3), or 0 for all/cancel.")
      chosen_main_events = utils::select.list(all_main_event_types, multiple = TRUE, title = "Select Main Event Type(s) (0 to cancel/select none):")
      if (length(chosen_main_events) == 0) {
        proceed_all = cli::cli_ask("No event types selected. Query for ALL event types for the specified geography?", default = "no")
        if(tolower(proceed_all) %in% c("y", "yes")){
          selected_event_types_api = NULL; selected_sub_event_types_api = NULL
          cli::cli_alert_info("Proceeding with ALL event types.")
        } else {
          cli::cli_abort("Event selection cancelled."); return(NULL)
        }
      } else {
        selected_event_types_api = chosen_main_events
        user_selected_sub_events = c()
        for (main_event in chosen_main_events) {
          available_subs = acled_event_taxonomy[[main_event]]$sub_event_types
          if (length(available_subs) > 0) {
            cli::cli_alert_info("For event type: {.val {main_event}}")
            choice_all_subs = utils::menu(c(paste("All sub-types for", main_event), "Select specific sub-types", "Skip sub-type selection for this event"), title = paste("Sub-event selection for:", main_event))
            if (choice_all_subs == 2) {
              chosen_subs = utils::select.list(available_subs, multiple = TRUE, title = paste("Select Sub-Event(s) for", main_event, "(0 to cancel for this event type):"))
              if (length(chosen_subs) > 0) user_selected_sub_events = c(user_selected_sub_events, chosen_subs)
            } else if (choice_all_subs == 1) {
              cli::cli_text("Including all sub-types for {.val {main_event}}.")
            } # if 3 (skip), do nothing
          }
        }
        if (length(user_selected_sub_events) > 0) selected_sub_event_types_api = unique(user_selected_sub_events)
        else selected_sub_event_types_api = NULL
      }
    }
  }

  # --- Parameter Definitions ---
  base_url_endpoint = "https://api.acleddata.com/acled/read"

  # --- Date Formatting ---
  tryCatch({
    start_date_formatted = format(as.Date(start_date), "%Y-%m-%d")
    end_date_formatted = format(as.Date(end_date), "%Y-%m-%d")
  }, error = function(e) {
    cli::cli_abort(c("Invalid {.arg start_date} or {.arg end_date}.", "i" = "Use 'YYYY-MM-DD' or Date objects.", "x" = e$message))
  })

  # --- Build Query STRING ---
  query_string_parts = c()

  query_string_parts = c(query_string_parts, paste0("key=", utils::URLencode(access_key, reserved = TRUE)))
  query_string_parts = c(query_string_parts, paste0("email=", utils::URLencode(email_address, reserved = TRUE)))
  query_string_parts = c(query_string_parts, paste0("event_date=", utils::URLencode(paste(start_date_formatted, end_date_formatted, sep = "|"), reserved = TRUE)))
  query_string_parts = c(query_string_parts, "event_date_where=BETWEEN")
  query_string_parts = c(query_string_parts, paste0("limit=", page_limit))

  if (!is.null(country)) query_string_parts = c(query_string_parts, paste0("country=", paste(sapply(country, utils::URLencode, reserved = TRUE), collapse = "|")))
  if (!is.null(region)) query_string_parts = c(query_string_parts, paste0("region=", paste(sapply(region, utils::URLencode, reserved = TRUE), collapse = "|")))
  if (!is.null(admin1)) query_string_parts = c(query_string_parts, paste0("admin1=", paste(sapply(admin1, utils::URLencode, reserved = TRUE), collapse = "|")))
  if (!is.null(admin2)) query_string_parts = c(query_string_parts, paste0("admin2=", paste(sapply(admin2, utils::URLencode, reserved = TRUE), collapse = "|")))
  if (!is.null(admin3)) query_string_parts = c(query_string_parts, paste0("admin3=", paste(sapply(admin3, utils::URLencode, reserved = TRUE), collapse = "|")))

  if (!is.null(selected_event_types_api) && length(selected_event_types_api) > 0) {
    query_string_parts = c(query_string_parts, paste0("event_type=", paste(sapply(selected_event_types_api, utils::URLencode, reserved = TRUE), collapse = "|")))
  }
  if (!is.null(selected_sub_event_types_api) && length(selected_sub_event_types_api) > 0) {
    query_string_parts = c(query_string_parts, paste0("sub_event_type=", paste(sapply(selected_sub_event_types_api, utils::URLencode, reserved = TRUE), collapse = "|")))
  }

  additional_params = list(...)
  if (length(additional_params) > 0) {
    for (param_name in names(additional_params)) {
      param_value = additional_params[[param_name]]
      query_string_parts = c(query_string_parts, paste0(utils::URLencode(param_name, reserved = TRUE), "=", utils::URLencode(as.character(param_value), reserved = TRUE)))
    }
  }

  base_query_string = paste(query_string_parts, collapse = "&")

  # --- Inform User about the Query ---
  cli::cli_h1("ACLED Direct API Request (Manual URL)")
  # For brevity, showing only some key parameters that were set
  # This avoids an extremely long cli_bullets output if base_query_string is huge
  summary_params = list(
    Dates = paste(start_date_formatted, "to", end_date_formatted),
    Country = if(!is.null(country)) paste(country, collapse=", ") else "Any",
    Region = if(!is.null(region)) paste(region, collapse=", ") else "Any",
    Admin1 = if(!is.null(admin1)) paste(admin1, collapse=", ") else "Any",
    `Event Types` = if(!is.null(selected_event_types_api)) paste(selected_event_types_api, collapse=", ") else "All",
    `SubEvent Types` = if(!is.null(selected_sub_event_types_api)) paste(selected_sub_event_types_api, collapse=", ") else "All for selected main types"
  )
  # Filter out "Any" or "All" for more concise display if they were NULL
  summary_params_display = Filter(function(x) ! (is.character(x) && (x == "Any" || x == "All" || x == "All for selected main types" && is.null(selected_event_types_api) ) ), summary_params)

  cli_bullet_points_text = character(length(summary_params_display))
  param_names_for_display = names(summary_params_display)
  for (i in seq_along(param_names_for_display)) {
    p_name  = param_names_for_display[i]
    p_value = as.character(summary_params_display[[p_name]])
    cli_bullet_points_text[i] = cli::format_inline("{p_name}: {.val {p_value}}")
  }
  names(cli_bullet_points_text) = rep("*", length(cli_bullet_points_text))
  cli::cli_bullets(c("*" = "Querying ACLED API with parameters:", cli_bullet_points_text))


  if (used_env_email) cli::cli_alert_info("Using email from {.envvar ACLED_EMAIL}.")
  if (used_env_key) cli::cli_alert_info("Using access key from {.envvar ACLED_API_KEY}.")

  # --- Pagination Loop ---
  all_data_list = list()
  current_page = 1
  total_expected_records = NA
  total_pages_approx = NA

  pb_id = NULL

  cli_process_id = cli::cli_process_start("Fetching data from ACLED API...",
                                          msg_done = "Finished fetching all pages.",
                                          msg_failed = "Failed to fetch all data.")

  repeat {
    current_page_query_string = paste0(base_query_string, "&page=", current_page)
    full_request_url = paste0(base_url_endpoint, "?", current_page_query_string)

    # Progress Bar Update - Placed before the API call for the current page
    if (!is.null(pb_id)) { # If progress bar exists
      if (!is.na(total_pages_approx) && total_pages_approx > 0) { # Determinate bar
        cli::cli_progress_update(id = pb_id, set = current_page, force = TRUE)
      } else { # Indeterminate bar (type="iterator")
        cli::cli_progress_update(id = pb_id, force = TRUE) # Just tick it
      }
    }

    display_url = if(nchar(full_request_url) > 150) paste0(substr(full_request_url, 1, 147), "...") else full_request_url
    cli::cli_alert_info("Requesting: {.url {display_url}} (Page {current_page})")

    resp = tryCatch({
      httr::GET(full_request_url, httr::user_agent("GenericACLEDClient/0.3-ManualURL"))
    }, error = function(e) {
      cli::cli_alert_danger("HTTP request failed (Page {current_page}): {e$message}")
      return(list(error = TRUE, message = e$message))
    })

    if (inherits(resp, "list") && !is.null(resp$error)) {
      cli::cli_process_failed(cli_process_id); if (!is.null(pb_id)) cli::cli_progress_done(id = pb_id); return(NULL)
    }
    if (httr::http_error(resp)) {
      cli::cli_alert_danger("API Error (Page {current_page}): HTTP {httr::status_code(resp)}")
      error_content = httr::content(resp, as = "text", encoding = "UTF-8")
      cli::cli_alert_danger("Response: {error_content}")
      try({
        json_error = jsonlite::fromJSON(error_content)
        if(!is.null(json_error$error) && !is.null(json_error$error$message)) cli::cli_alert_danger("API Message: {json_error$error$message}")
      }, silent = TRUE)
      cli::cli_process_failed(cli_process_id); if (!is.null(pb_id)) cli::cli_progress_done(id = pb_id); return(NULL)
    }

    num_records_this_page = 0
    page_data_df = NULL

    if (httr::http_type(resp) == "application/json") {
      page_content_text = httr::content(resp, as = "text", encoding = "UTF-8")
      page_content = tryCatch(jsonlite::fromJSON(page_content_text, flatten = TRUE), error = function(e) {
        cli::cli_alert_danger("JSON parsing error: {e$message}"); cli::cli_alert_info("Text: {substr(page_content_text,1,500)}"); NULL
      })
      if (is.null(page_content)) { cli::cli_process_failed(cli_process_id); if(!is.null(pb_id)) cli::cli_progress_done(id=pb_id); return(NULL) }

      if (!is.null(page_content$data) && (is.data.frame(page_content$data) || (is.list(page_content$data) && length(page_content$data) > 0))) {
        page_data_df = as.data.frame(page_content$data)
      }
      if (is.null(page_data_df) || nrow(page_data_df) == 0) {
        if (!is.null(page_content$error) && !is.null(page_content$error$message)) cli::cli_alert_danger("API error: {page_content$error$message}")
        else if (!is.null(page_content$messages) && length(page_content$messages)>0 && nzchar(paste(page_content$messages,collapse=''))) cli::cli_alert_info("API Message: {paste(page_content$messages,collapse='; ')}")
        if (current_page == 1) cli::cli_alert_warning("No data for query.") else cli::cli_alert_info("No more data.")
        break
      }
      if (current_page == 1 && !is.null(page_content$count) && is.numeric(page_content$count)) {
        total_expected_records = as.integer(page_content$count)
        cli::cli_alert_info("API reports {total_expected_records} total records for this query.")
        if (total_expected_records > page_limit) {
          total_pages_approx = ceiling(total_expected_records / page_limit)
          if (total_pages_approx > 1 && total_pages_approx < (max_pages + 5)) {
            pb_id = cli::cli_progress_bar(name = "Downloading Pages", total = total_pages_approx, clear = FALSE, .auto_close = FALSE)
            cli::cli_progress_update(id = pb_id, set = 1, force = TRUE) # Already fetched page 1
          } else { cli::cli_alert_info("Large page count; determinate progress bar disabled.") }
        } else if (total_expected_records > 0) { total_pages_approx = 1; cli::cli_alert_info("All data expected on one page.") }
        else { total_pages_approx = 0; cli::cli_alert_info("API reports 0 records.") }
      }
      all_data_list[[current_page]] = page_data_df
      num_records_this_page = nrow(page_data_df)

    } else if (httr::http_type(resp) == "text/csv") {
      page_text = httr::content(resp, as = "text", encoding = "UTF-8")
      if (grepl("Error: No data found", page_text, ignore.case=T) || nchar(trimws(page_text)) < 50) { if(current_page==1) cli::cli_alert_warning("No data.") else cli::cli_alert_info("No more data."); break }
      page_df = tryCatch(utils::read.csv(text=page_text, stringsAsFactors=F, na.strings=c("NA","")), error=function(e){ cli::cli_alert_warning("CSV parse error: {e$message}"); NULL })
      if(is.null(page_df) || nrow(page_df)==0) { if(current_page==1) cli::cli_alert_warning("No data (CSV empty).") else cli::cli_alert_info("No more data (CSV empty)."); break }
      all_data_list[[current_page]] = page_df
      num_records_this_page = nrow(page_df)
      if (current_page == 1) {
        total_expected_records = -1 # Mark as unknown for CSV
        if (num_records_this_page == page_limit && is.null(pb_id)) { # If first page is full, init indeterminate PB
          pb_id = cli::cli_progress_bar(name = "Downloading Pages (CSV)", type = "iterator", clear = FALSE, .auto_close = FALSE)
          cli::cli_progress_update(id = pb_id) # Tick for page 1
        }
      }
    } else {
      cli::cli_alert_warning("Unexpected content type: {httr::http_type(resp)}."); cli::cli_text("Content: {substr(httr::content(resp,as='text'),1,200)}..."); break
    }

    if (num_records_this_page < page_limit) { cli::cli_alert_info("Fetched {num_records_this_page} records. Last page."); break }
    current_page = current_page + 1
    if (current_page > max_pages) { cli::cli_alert_warning("Max pages ({max_pages}) reached."); break }
    Sys.sleep(0.5)
  } # End repeat

  if (!is.null(pb_id)) {
    # Ensure progress bar is marked as complete or reflects final state
    if (!is.na(total_pages_approx) && total_pages_approx > 0) {
      final_set_value = min(current_page -1, total_pages_approx) # current_page might be one ahead if loop broke
      if (num_records_this_page < page_limit) final_set_value = total_pages_approx # If last page, complete it
      cli::cli_progress_update(id = pb_id, set = final_set_value, total = total_pages_approx, force = TRUE)
    }
    cli::cli_progress_done(id = pb_id)
  }
  cli::cli_process_done(cli_process_id)

  if (length(all_data_list) == 0) { cli::cli_alert_warning("No data collected."); return(NULL) }

  # --- Combine all pages ---
  final_df = tryCatch({
    if (!requireNamespace("dplyr", quietly = TRUE)) {
      cli::cli_alert_info("Using base R rbind. For robust binding, install {.pkg dplyr}.")
      if (length(all_data_list) > 1) {
        all_cols = unique(unlist(lapply(all_data_list, names)))
        all_data_list_filled = lapply(all_data_list, function(df) {
          missing_cols = all_cols[!all_cols %in% names(df)]; if (length(missing_cols) > 0) df[missing_cols] = NA
          df[, all_cols, drop = FALSE]
        })
        do.call(rbind, all_data_list_filled)
      } else if (length(all_data_list) == 1) all_data_list[[1]]
      else data.frame()
    } else dplyr::bind_rows(all_data_list)
  }, error = function(e){
    cli::cli_alert_danger("Failed to combine pages: {e$message}")
    if(output_format == "raw_json") return(all_data_list) else return(NULL)
  })

  if (output_format == "raw_json" && inherits(final_df, "list") && !is.data.frame(final_df)) {
    cli::cli_alert_success("Returning list of data from each page."); return(final_df)
  } else if ((inherits(final_df, "list") && !is.data.frame(final_df)) && output_format == "df"){
    cli::cli_alert_warning("Could not produce single data.frame."); return(NULL)
  }
  if (is.null(final_df)) { cli::cli_alert_warning("Final data frame is NULL."); return(NULL) }

  if (nrow(final_df) == 0) cli::cli_alert_info("Final combined data is empty.")
  else {
    data_type_msg = if(output_format == "df") "data.frame" else "list of page data"
    cli::cli_alert_success("Successfully prepared {nrow(final_df)} event{?s} as a {data_type_msg}.")
  }
  return(final_df)
}
