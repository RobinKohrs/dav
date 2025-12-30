#' Create a Formatted Timestamp String
#'
#' Generates a timestamp string with specific formatting options, focusing on
#' German natural language formats (e.g., "9. Dezember um 7:20 Uhr").
#'
#' @param x A `POSIXct`, `POSIXt`, or `Date` object. Defaults to `Sys.time()`.
#' @param format A character string specifying the format.
#'   Options include:
#'   - `"de_text"`: "9. Dezember um 7:20 Uhr" (Default)
#'   - `"de_date"`: "9. Dezember 2025"
#'   - `"de_short"`: "09.12.2025"
#'   - Any valid standard format string (e.g., `"%Y-%m-%d"`).
#' @param tz Timezone specification to be used for the conversion,
#'   if available. Defaults to the timezone attribute of `x` or system default.
#'   You can pass, e.g., "Europe/Vienna".
#'
#' @return A character string of the formatted date.
#' @export
#' @examples
#' dw_timestamp()
#' dw_timestamp(format = "de_date")
dw_timestamp <- function(x = Sys.time(), format = "de_text", tz = "") {
  # Handle timezone if specified and x is POSIXt
  if (inherits(x, "POSIXt") && tz != "") {
    x <- as.POSIXct(x)
    attr(x, "tzone") <- tz
  }

  german_months <- c(
    "Januar",
    "Februar",
    "März",
    "April",
    "Mai",
    "Juni",
    "Juli",
    "August",
    "September",
    "Oktober",
    "November",
    "Dezember"
  )

  if (format == "de_text") {
    # "9. Dezember um 7:20 Uhr"
    day <- as.integer(format(x, "%d"))
    month_idx <- as.integer(format(x, "%m"))
    month_name <- german_months[month_idx]
    hour <- as.integer(format(x, "%H"))
    minute <- format(x, "%M")

    return(sprintf("%d. %s um %d:%s Uhr", day, month_name, hour, minute))
  } else if (format == "de_date") {
    # "9. Dezember 2025"
    day <- as.integer(format(x, "%d"))
    month_idx <- as.integer(format(x, "%m"))
    month_name <- german_months[month_idx]
    year <- format(x, "%Y")

    return(sprintf("%d. %s %s", day, month_name, year))
  } else if (format == "de_short") {
    # "09.12.2025"
    return(format(x, "%d.%m.%Y"))
  } else {
    # Fallback to standard format
    return(format(x, format))
  }
}
