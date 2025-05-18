#' Download File from HDX Page
#'
#' Downloads a file from an HDX dataset page using a CSS selector
#' to find the download link.
#'
#' @param page_url The full URL of the HDX dataset page.
#' @param css_selector The CSS selector to identify the download link <a> tag.
#' @param base_url The base URL of the HDX site (e.g., "https://data.humdata.org").
#' @return Path to the downloaded temporary file.
#'
#' @importFrom rvest read_html html_element html_attr
#' @importFrom xml2 url_absolute
#' @importFrom httr GET write_disk user_agent stop_for_status
#' @importFrom tools file_ext
#' @importFrom utils packageName packageVersion
#' @importFrom cli cli_alert_info
#'
humdata_download_file = function(page_url,
                                 css_selector = "a.resource-download-button",
                                 base_url = "https://data.humdata.org") {

  html_page = tryCatch({
    rvest::read_html(page_url)
  }, error = function(e) {
    stop("Failed to read HTML from: ", page_url, "\nError: ", e$message, call. = FALSE)
  })

  download_node = rvest::html_element(html_page, css = css_selector)

  if (inherits(download_node, "xml_missing")) {
    stop("Could not find a download link using CSS selector '", css_selector, "' on page ", page_url, call. = FALSE)
  }

  relative_download_url = rvest::html_attr(download_node, "href")
  if (is.na(relative_download_url) || nchar(relative_download_url) == 0) {
    stop("Download link found, but it has no 'href' attribute.", call. = FALSE)
  }
  absolute_download_url = xml2::url_absolute(relative_download_url, base_url)

  file_name_from_url = basename(absolute_download_url)
  file_ext_from_url = tools::file_ext(file_name_from_url)
  temp_file_ext = if (nzchar(file_ext_from_url)) paste0(".", file_ext_from_url) else ".dat"
  # Using utils::tempfile explicitly for clarity, though just tempfile() works
  temp_file_path = tempfile(fileext = temp_file_ext)


  ua_string_minimal = "R_Package_Downloader/0.1"
  pkg_name_current = utils::packageName()
  if (!is.null(pkg_name_current) && nzchar(pkg_name_current) && pkg_name_current != ".GlobalEnv") {
    pkg_version_current = tryCatch(as.character(utils::packageVersion(pkg_name_current)), error = function(e) "dev")
    ua_string_minimal = paste0(pkg_name_current, "/", pkg_version_current)
  }

  # Informative message before starting the download
  cli::cli_alert_info("Attempting to download data from HDX: {.url {absolute_download_url}}")

  response = tryCatch({
    httr::GET(
      url = absolute_download_url,
      httr::write_disk(temp_file_path, overwrite = TRUE),
      httr::user_agent(ua_string_minimal)
    )
  }, error = function(e) {
    if (file.exists(temp_file_path)) unlink(temp_file_path, force = TRUE)
    stop("Failed to download file from: ", absolute_download_url, "\nNetwork Error: ", e$message, call. = FALSE)
  })

  tryCatch({
    httr::stop_for_status(response, task = paste("downloading", basename(absolute_download_url)))
  }, error = function(e_http) {
    if (file.exists(temp_file_path)) unlink(temp_file_path, force = TRUE)
    stop("HTTP error during download from ", absolute_download_url, ".\n", e_http$message, call. = FALSE)
  })

  if (!file.exists(temp_file_path) || file.info(temp_file_path)$size == 0) {
    if (file.exists(temp_file_path)) unlink(temp_file_path, force = TRUE)
    stop("Download completed but resulted in an empty or non-existent file: ", temp_file_path, call. = FALSE)
  }
  return(temp_file_path)
}
