#' Data on people killed in the gaza strip
#'
#' @title Download and Read "Killed in Gaza" Data from HDX
#' @description This function downloads the "Killed in Gaza" dataset from the
#'   Humanitarian Data Exchange (HDX) page for "The State of Palestine -
#'   Escalation of Hostilities". It then reads the downloaded Excel file
#'   and returns its content as a tibble.
#'
#' @details The function specifies the HDX page URL for the "Killed in Gaza"
#'   data, calls an internal helper (`humdata_download_file`) to download the file
#'   to a temporary location, reads the data from the first sheet of the Excel
#'   file using `readxl::read_excel()`, and then deletes the temporary file.
#'   Column names are cleaned using `janitor::clean_names()`.
#'
#' @param sheet The sheet to read from the Excel file. Can be a string (sheet name)
#'   or an integer (sheet number). Defaults to `1` (the first sheet).
#' @param ... Additional arguments to pass to `readxl::read_excel()`.
#'
#' @return A tibble containing the data from the "Killed in Gaza" Excel file.
#' @export
#'
#' @importFrom readxl read_excel
#' @importFrom janitor clean_names
#' @importFrom cli cli_alert_info cli_alert_success
#'
#' @examples
#' \dontrun{
#'   try({
#'     # Ensure you have an internet connection for this example to run.
#'     killed_data = gaza_people_killed()
#'     print(head(killed_data))
#'   }, error = function(e) {
#'     message("An error occurred during the example: ", e$message)
#'   })
#' }
gaza_people_killed = function(sheet = 1) {

  killed_in_gaza_page_url = "https://data.humdata.org/dataset/the-state-of-palestine-escalation-of-hostilities"
  cli::cli_alert_info("Initiating download for 'Killed in Gaza' data.")

  # Call the generic HDX download helper function
  temp_file_path = humdata_download_file(page_url = killed_in_gaza_page_url)
  cli::cli_alert_info("File downloaded to temporary path: {.path {temp_file_path}}")

  # Read the data from the downloaded Excel file
  data_content = tryCatch({
    readxl::read_excel(temp_file_path, sheet = sheet)
  }, error = function(e) {
    # Clean up the temp file even if reading fails
    if (file.exists(temp_file_path)) {
      unlink(temp_file_path, force = TRUE)
    }
    stop("Failed to read the downloaded Excel file: ", temp_file_path, "\nError: ", e$message, call. = FALSE)
  })

  # Clean up the temporary file after successfully reading it
  if (file.exists(temp_file_path)) {
    unlink(temp_file_path, force = TRUE)
  }

  if (inherits(data_content, "data.frame")) {
    data_content = janitor::clean_names(data_content)
    cli::cli_alert_info("Column names cleaned.")
  } else if (!is.null(data_content)) { # Only issue warning if data_content exists but isn't a df
    cli::cli_alert_warning("Column names not cleaned: input was not a data frame.")
  }
  # If data_content is NULL, the error for reading would have already occurred.

  cli::cli_alert_success("'Killed in Gaza' data downloaded and read successfully.")
  return(data_content)
}
