#' Download ACLED Data for Explosion Events in the Gaza Strip
#'
#' This is a specific wrapper function that calls `acled_download_events`
#' to download data for events classified as "Explosions/Remote violence"
#' in the Gaza Strip, Palestine.
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
#' @param sub_event_types Character vector. Optional. Specific sub-event type(s)
#'                        under "Explosions/Remote violence" to filter by.
#'                        If `NULL` (default), all "Explosions/Remote violence" events are included.
#'                        Example: `c("Air/drone strike", "Shelling/artillery/missile attack")`.
#' @param page_limit Numeric. Records per API page request.
#' @param max_pages Numeric. Maximum pages to fetch to prevent overly long requests.
#' @param output_format Character. "df" for a data.frame or "raw_json" for raw list.
#' @param ... Additional arguments to be passed to `acled_download_events`
#'            (and subsequently to the ACLED API).
#'
#' @return A data.frame containing the queried ACLED event data (if `output_format = "df"`),
#'         or a list of parsed JSON content from each page (if `output_format = "raw_json"`).
#'         Returns NULL if a critical error occurs or no data is found.
#' @export
#' @seealso [acled_download_events()]
#' @examples
#' \dontrun{
#' # --- Set environment variables first (recommended) ---
#' # Sys.setenv(ACLED_EMAIL = "YOUR_EMAIL")
#' # Sys.setenv(ACLED_API_KEY = "YOUR_ACCESS_KEY")
#'
#' # Get all explosion events in Gaza for a specific week
#' gaza_explosions_week = acled_gaza_explosions(
#'   start_date = "2023-10-01",
#'   end_date = "2023-10-07"
#' )
#'
#' if (!is.null(gaza_explosions_week) && nrow(gaza_explosions_week) > 0) {
#'   print(head(gaza_explosions_week[, c("event_date", "admin1", "location", "event_type", "sub_event_type")]))
#'   print(table(gaza_explosions_week$sub_event_type))
#' }
#'
#' # Get only Air/drone strikes and Shelling in Gaza for a specific day
#' gaza_specific_strikes_day = acled_gaza_explosions(
#'   start_date = "2023-10-08",
#'   end_date = "2023-10-08",
#'   sub_event_types = c("Air/drone strike", "Shelling/artillery/missile attack")
#' )
#'
#' if (!is.null(gaza_specific_strikes_day) && nrow(gaza_specific_strikes_day) > 0) {
#'   print(table(gaza_specific_strikes_day$sub_event_type))
#' }
#' }
acled_gaza_explosions = function(email_address = NULL,
                                 access_key = NULL,
                                 start_date,
                                 end_date,
                                 sub_event_types = NULL, # Kept this specific for explosions
                                 page_limit = 5000,
                                 max_pages = 100,
                                 output_format = "df",
                                 ...) {

  # Call the general function with fixed parameters for Gaza explosions
  acled_download_events(
    email_address = email_address,
    access_key = access_key,
    start_date = start_date,
    end_date = end_date,
    country = "Palestine",
    admin1 = "Gaza Strip",
    event_types = "Explosions/Remote violence",
    sub_event_types = sub_event_types, # Pass through user's sub-event choice for explosions
    interactive_events = FALSE, # This wrapper is not interactive for event_types
    page_limit = page_limit,
    max_pages = max_pages,
    output_format = output_format,
    ... # Pass through any other arguments
  )
}
