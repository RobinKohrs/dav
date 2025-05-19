#' Gaza Commodity Prices
#'
#' @title Download and Process Gaza Commodity Price Data
#' @description Downloads commodity price data for Gaza from the Humanitarian
#'   Data Exchange (HDX), processes it into a tidy format, and can translate
#'   commodity names to German.
#'
#' @details The function fetches the Excel file from the "State of Palestine -
#'   Price of basic commodities in Gaza" dataset on HDX. It cleans the column
#'   names, identifies relevant commodity and price columns, and pivots the data
#'   into a long format. Dates are parsed: one special column representing
#'   October 2023 data is assigned `2023-10-01`, and others are derived from
#'   Excel serial date numbers present in column headers (e.g., "Nov-23" becomes
#'   `x45231` then `2023-11-01`). Commodity names (English) can be translated.
#'   The output is a tibble with columns: `commodity_name_english`,
#'   `commodity_name_german` (optional), `date`, and `absolute_price`.
#'
#' @param translate_names Logical. If `TRUE` (default), attempts to translate
#'   commodity names to German using `polyglotr::google_translate`. Requires
#'   the `polyglotr` package. If `FALSE` or `polyglotr` is not available,
#'   `commodity_name_german` will be `NA`.
#'
#' @return A tibble with processed commodity price data. Columns include:
#'   \itemize{
#'     \item `commodity_name_english`: Original commodity name in English.
#'     \item `commodity_name_german`: Translated commodity name in German (or NA if translation off/failed).
#'     \item `date`: The date of the price observation.
#'     \item `absolute_price`: The price of the commodity.
#'   }
#' @export
#'
#' @importFrom readxl read_excel
#' @importFrom janitor clean_names
#' @importFrom dplyr select all_of filter mutate case_when sym rename arrange distinct if_else
#' @importFrom tidyr pivot_longer
#' @importFrom lubridate ymd
#' @importFrom stringr str_remove
#' @importFrom rlang .data
#' @importFrom cli cli_alert_info cli_alert_warning cli_alert_success
#'
#' @examples
#' \dontrun{
#'   try({
#'     gaza_prices = gaza_commodity_prices()
#'     print(head(gaza_prices))
#'
#'     # Example if polyglotr is not installed or translation is off:
#'     # gaza_prices_no_translate = gaza_commodity_prices(translate_names = FALSE)
#'     # print(head(gaza_prices_no_translate))
#'   }, error = function(e) {
#'     message("Error in example: ", e$message)
#'     message("This might be due to network issues, API limits, or changes in data source.")
#'   })
#' }
gaza_commodity_prices = function(translate_names = TRUE) {
  hdx_page_url = "https://data.humdata.org/dataset/state-of-palestine-price-of-basic-commodities-in-gaza"
  cli::cli_alert_info("Initiating download and processing for Gaza commodity prices.")

  # Assuming humdata_download_file is in the same package and @noRd
  temp_file_path = humdata_download_file(page_url = hdx_page_url)
  cli::cli_alert_info("File downloaded to temporary path: {.path {temp_file_path}}")

  df_raw = tryCatch({
    readxl::read_excel(temp_file_path) # Ensure "Prices" is the correct sheet name
  }, error = function(e) {
    stop("Failed to read the Excel file from: ", temp_file_path, "\nError: ", e$message, call. = FALSE)
  })

  unlink(temp_file_path)

  df_cleaned = janitor::clean_names(df_raw) %>% select(-matches("x1"))
  cli::cli_alert_info("Excel sheet read and column names cleaned.")

  commodity_col_cleaned = "commodity_name_english"
  special_price_col_cleaned = "average_price_after_7_october_2023"
  excel_serial_date_col_regex = "^x\\d+$" # Matches 'x' followed by one or more digits

  excel_serial_price_cols_cleaned = grep(excel_serial_date_col_regex, names(df_cleaned), value = TRUE)

  # all_price_cols_to_pivot = c()
  # if (special_price_col_cleaned %in% names(df_cleaned)) {
  #   all_price_cols_to_pivot = c(all_price_cols_to_pivot, special_price_col_cleaned)
  # }
  all_price_cols_to_pivot = c(excel_serial_price_cols_cleaned)
  all_price_cols_to_pivot = unique(all_price_cols_to_pivot)

  if (!(commodity_col_cleaned %in% names(df_cleaned))) {
    stop("Essential commodity column '", commodity_col_cleaned, "' not found after cleaning names.", call. = FALSE)
  }
  if (length(all_price_cols_to_pivot) == 0) {
    stop(
      "No price columns identified for pivoting. Check expected column names and patterns.",
      call. = FALSE
    )
  }
  cli::cli_alert_info("Identified {length(all_price_cols_to_pivot)} price column(s) for processing.")

  df_long = df_cleaned %>%
    dplyr::select(dplyr::all_of(c(commodity_col_cleaned, all_price_cols_to_pivot))) %>%
    tidyr::pivot_longer(
      cols = dplyr::all_of(all_price_cols_to_pivot),
      names_to = "price_source_column_name",
      values_to = "absolute_price",
      values_drop_na = TRUE
    )

  df_dated = df_long %>%
    dplyr::mutate(
      date = dplyr::case_when(
        .data$price_source_column_name == special_price_col_cleaned ~ lubridate::ymd("2023-10-01"), # Assign 1st Oct for this column
        grepl(excel_serial_date_col_regex, .data$price_source_column_name) ~
          as.Date(
            as.numeric(stringr::str_remove(.data$price_source_column_name, "^x")),
            origin = "1899-12-30" # Explicitly using as.Date with origin
          ),
        TRUE ~ NA
      )
    ) %>%
    dplyr::filter(!is.na(.data$date), !is.na(.data$absolute_price)) %>%
    dplyr::select(
      commodity_name_english = !!dplyr::sym(commodity_col_cleaned),
      date = .data$date,
      absolute_price = .data$absolute_price
    ) %>%
    dplyr::arrange(.data$commodity_name_english, .data$date)

  cli::cli_alert_info("Data pivoted and dates processed.")

  if (translate_names) {
    if (requireNamespace("polyglotr", quietly = TRUE)) {
      cli::cli_alert_info("Attempting to translate commodity names to German...")
      unique_english_names_df = df_dated %>%
        dplyr::filter(!is.na(.data$commodity_name_english) & .data$commodity_name_english != "") %>%
        dplyr::distinct(.data$commodity_name_english)

      if (nrow(unique_english_names_df) > 0) {
        unique_english_names = unique_english_names_df$commodity_name_english
        translated_names_list = tryCatch({
          polyglotr::google_translate(
            unique_english_names,
            target_language = "de",
            source_language = "en"
          )
        }, error = function(e) {
          warning("Google Translate API call failed: ", e$message,
                  "\nGerman names will be NA. Check API key, internet, or package setup.", call. = FALSE)
          NULL
        })

        if (!is.null(translated_names_list) && length(translated_names_list) == length(unique_english_names)) {
          translation_map = stats::setNames(translated_names_list, unique_english_names)
          df_dated = df_dated %>%
            dplyr::mutate(
              commodity_name_german = translation_map[.data$commodity_name_english]
            )
          cli::cli_alert_info("Translation successful for {sum(!is.na(translation_map))} names.")
        } else {
          df_dated$commodity_name_german = NA_character_
          if(is.null(translated_names_list)) {
            cli::cli_alert_warning("Translation API call returned NULL.")
          } else {
            cli::cli_alert_warning("Mismatch in translated names length. Translation might be incomplete.")
          }
        }
      } else {
        df_dated$commodity_name_german = NA_character_
        cli::cli_alert_info("No valid English commodity names found to translate.")
      }
    } else {
      warning("Package 'polyglotr' is not installed, but 'translate_names' is TRUE. German names will be NA.", call. = FALSE)
      df_dated$commodity_name_german = NA_character_
    }
  } else {
    df_dated$commodity_name_german = NA_character_
    cli::cli_alert_info("Translation of commodity names skipped.")
  }

  final_cols = c("commodity_name_english")
  if ("commodity_name_german" %in% names(df_dated)) {
    final_cols = c(final_cols, "commodity_name_german")
  }
  final_cols = c(final_cols, "date", "absolute_price")

  df_final = df_dated %>% dplyr::select(dplyr::all_of(final_cols))

  cli::cli_alert_success("Gaza commodity price data processed successfully.")
  return(df_final)
}
