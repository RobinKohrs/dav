#' Create a Customized Data Frame Search Function
#'
#' This function acts as a factory, returning another function that is tailored
#' to search within a specific data frame (or sf object). The returned search
#' function can perform case-insensitive regular expression searches or fuzzy
#' string matching.
#'
#' @param df A data.frame or an sf object to be searched.
#' @param default_cols An optional character vector of column names to be used as
#'   the default set for searching by the returned function. If `NULL` (the default),
#'   and no columns are specified in a call to the returned search function,
#'   all character and factor columns of `df` will be searched. For `sf` objects,
#'   the geometry column is automatically excluded from this default.
#'   If specified columns are not character or factor, they will be coerced to
#'   character for searching, with a warning when the search function is used.
#'
#' @return A new function with the following signature:
#'   `function(pattern, fuzzy = FALSE, top_n = 3, fuzzy_method = "osa", cols = NULL)`
#'   \describe{
#'     \item{`pattern`}{A character string (regex or plain text for fuzzy) to search for.}
#'     \item{`fuzzy`}{Logical. If `TRUE`, performs fuzzy matching using the
#'       `stringdist` package to find the `top_n` most similar rows.
#'       Defaults to `FALSE` (regex search). The `stringdist` package must be
#'       installed and will be imported by this package.}
#'     \item{`top_n`}{Integer. If `fuzzy = TRUE`, the number of best matches to return.
#'       Defaults to 3.}
#'     \item{`fuzzy_method`}{Character. The method for `stringdist` calculation if `fuzzy = TRUE`.
#'       Defaults to "osa" (Optimal String Alignment). See `?stringdist::stringdistmethods`
#'       for other options.}
#'     \item{`cols`}{An optional character vector of column names to search within
#'       for *this specific call*. If provided, this overrides any `default_cols`
#'       set when `ff` was called. If `NULL` (the default), the search will use
#'       the `default_cols` (if provided to `ff`) or all character/factor columns
#'       if no `default_cols` were set.}
#'   }
#'   This returned function will take a `pattern` and search the data frame
#'   originally passed to `ff`, returning the matching rows.
#'
#' @export
#' @importFrom stringdist stringdist
#'
#' @examples
#' # Create a sample data frame
#' my_data = data.frame(
#'   ID = 1:5,
#'   Name = c("Apple Pie", "Banana Bread", "Cherry Cake", "Date Squares", "Elderflower Tea"),
#'   Category = factor(c("Dessert", "Baked Good", "Dessert", "Snack", "Beverage")),
#'   Description = c("Sweet apple filling", "Moist banana loaf",
#'                   "Rich cherry flavor", "Chewy dates", "Refreshing floral drink"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # 1. Searcher with no default columns (will search all char/factor cols by default)
#' search_all_defaults = ff(my_data)
#' search_all_defaults("apple") # Searches Name, Category, Description
#' search_all_defaults("apple", cols = "Name") # Overrides to search only Name
#' search_all_defaults("Dessert", cols = c("Name", "Category")) # Searches specified
#'
#' # 2. Searcher with default columns specified
#' search_name_default = ff(my_data, default_cols = "Name")
#' search_name_default("apple") # Searches only Name (default)
#' search_name_default("Dessert") # Searches only Name (default), won't find
#' search_name_default("Dessert", cols = "Category") # Overrides to search Category
#' search_name_default("Bread", cols = c("Name", "Description")) # Override
#'
#' # 3. Searcher with multiple default columns
#' search_name_cat_default = ff(my_data, default_cols = c("Name", "Category"))
#' search_name_cat_default("apple") # Searches Name and Category
#' search_name_cat_default("Baked") # Finds in Category
#' search_name_cat_default("filling", cols = "Description") # Overrides
#'
#' # Fuzzy search with override
#' search_all_defaults("Banna Bred", fuzzy = TRUE, top_n = 1) # Uses default cols
#' search_all_defaults("Banna Bred", fuzzy = TRUE, top_n = 1, cols="Name") # Uses override
#'
#' # Error if default_cols in ff don't exist
#' # try(ff(my_data, default_cols = "NonExistentCol"))
#'
#' # Error if cols in searcher don't exist
#' # try(search_all_defaults("test", cols = "NonExistentCol"))
ff = function(df, default_cols = NULL) {
  # --- Initial checks for ff ---
  if (!is.data.frame(df) && !inherits(df, "sf")) {
    stop("Input 'df' must be a data.frame or an sf object.")
  }

  .df_orig = df
  .default_cols_from_ff = default_cols # Store the default cols from ff

  # Validate .default_cols_from_ff IF IT IS NOT NULL, at ff creation time
  if (!is.null(.default_cols_from_ff)) {
    if (!is.character(.default_cols_from_ff) || length(.default_cols_from_ff) == 0) {
      stop("'default_cols' must be a character vector of column names.", call. = FALSE)
    }
    if (!all(.default_cols_from_ff %in% names(.df_orig))) {
      missing_cols = .default_cols_from_ff[!.default_cols_from_ff %in% names(.df_orig)]
      stop(paste("Specified 'default_cols' not found in dataframe:", paste(missing_cols, collapse = ", ")), call. = FALSE)
    }
  }

  # --- This is the function that will be returned ---
  search_in_df = function(pattern, fuzzy = FALSE, top_n = 3, fuzzy_method = "osa", cols = NULL) {
    # --- Checks for the returned search function ---
    if (!is.character(pattern) || length(pattern) != 1) {
      stop("'pattern' must be a single string.", call. = FALSE)
    }
    if (pattern == "" && !fuzzy) {
      warning("Empty pattern provided for regex search. This may match rows where specified/auto-selected columns have empty strings or can be coerced to match an empty string.", call. = FALSE)
    } else if (pattern == "" && fuzzy) {
      warning("Empty pattern provided for fuzzy search. Results might be unpredictable, likely matching rows with minimal content in searched columns.", call. = FALSE)
    }

    # Determine the actual columns to search for this specific call
    actual_cols_to_search_names = NULL

    if (!is.null(cols)) { # `cols` argument of search_in_df is used (override)
      if (!is.character(cols) || (length(cols) == 0 && !is.null(cols)) ) { # Allow cols=NULL, but not cols=character(0) without intention
        stop("Override 'cols' must be a character vector of column names or NULL.", call. = FALSE)
      }
      if (length(cols) > 0 && !all(cols %in% names(.df_orig))) { # Only check if cols is not empty
        missing_override_cols = cols[!cols %in% names(.df_orig)]
        stop(paste("Specified 'cols' for search (override) not found in dataframe:", paste(missing_override_cols, collapse = ", ")), call. = FALSE)
      }
      actual_cols_to_search_names = cols
    } else if (!is.null(.default_cols_from_ff)) { # No override, use default from ff
      actual_cols_to_search_names = .default_cols_from_ff
      # These were already validated in ff for existence
    } else { # No override, no default from ff: use all char/factor
      col_is_char_or_factor = sapply(.df_orig, function(x) is.character(x) || is.factor(x))
      actual_cols_to_search_names = names(.df_orig)[col_is_char_or_factor]

      if (inherits(.df_orig, "sf")) {
        sf_geom_col_name = attr(.df_orig, "sf_column")
        if (!is.null(sf_geom_col_name) && sf_geom_col_name %in% actual_cols_to_search_names) {
          actual_cols_to_search_names = setdiff(actual_cols_to_search_names, sf_geom_col_name)
        }
      }

      if (length(actual_cols_to_search_names) == 0) {
        message("No character or factor columns found to search by default, and no specific columns provided. Returning empty data frame.")
        return(.df_orig[0L, , drop = FALSE])
      }
    }

    # If actual_cols_to_search_names is empty (e.g. cols = character(0) was passed),
    # data_for_search_content will have 0 columns.
    if (length(actual_cols_to_search_names) == 0) {
      # This handles explicit request to search zero columns.
      # The fuzzy/regex search parts will return an empty df of original schema.
      data_for_search_content = .df_orig[ , actual_cols_to_search_names, drop = FALSE] # 0-col df
    } else {
      data_for_search_content = .df_orig[, actual_cols_to_search_names, drop = FALSE]
    }


    # Warn if any of the *selected* columns are not character/factor
    if (ncol(data_for_search_content) > 0) { # Only if there are columns to check
      is_char_factor_in_selected = sapply(data_for_search_content, function(x) is.character(x) || is.factor(x))
      if (sum(!is_char_factor_in_selected) > 0) {
        non_char_cols_selected = names(data_for_search_content)[!is_char_factor_in_selected]
        warning(paste("The following selected columns for search are not character/factor and will be coerced to character:",
                      paste(non_char_cols_selected, collapse=", ")), call. = FALSE)
      }
      # Coerce selected columns to character for searching
      data_for_search_content = as.data.frame(
        lapply(data_for_search_content, as.character),
        stringsAsFactors = FALSE
      )
    }
    # else: data_for_search_content has 0 columns, no coercion needed / possible


    # --- Perform the search ---
    if (fuzzy) {
      if (nrow(data_for_search_content) == 0 || ncol(data_for_search_content) == 0) {
        return(.df_orig[0L, , drop=FALSE])
      }

      concatenated_row_strings = apply(data_for_search_content, 1, function(row_vector) {
        row_vector[is.na(row_vector)] = ""
        paste(row_vector, collapse = " \f ")
      })

      distances = stringdist::stringdist(tolower(pattern), tolower(concatenated_row_strings), method = fuzzy_method)

      if (length(distances) == 0) return(.df_orig[0L, , drop = FALSE])

      ordered_indices = order(distances)
      num_results_to_return = min(as.integer(top_n), length(ordered_indices), nrow(.df_orig))

      if (num_results_to_return <= 0) return(.df_orig[0L, , drop = FALSE])

      result_indices = ordered_indices[1:num_results_to_return]
      return(.df_orig[result_indices, , drop = FALSE])

    } else { # Regex search
      if (nrow(data_for_search_content) == 0 || ncol(data_for_search_content) == 0) {
        return(.df_orig[0L, , drop=FALSE])
      }

      match_matrix = sapply(data_for_search_content, function(column_vector) {
        grepl(pattern, column_vector, ignore.case = TRUE)
      })

      if (!is.matrix(match_matrix) && length(match_matrix) > 0) {
        match_matrix = matrix(match_matrix, ncol = 1)
      } else if (length(match_matrix) == 0 && nrow(data_for_search_content) > 0 && ncol(data_for_search_content) > 0) {
        # This case means match_matrix is empty but shouldn't be if data_for_search_content has cols.
        # This scenario should be rare given the structure. If ncol > 0, sapply should return something.
        # However, if data_for_search_content has rows but zero columns, apply below will fail.
        # The nrow/ncol check above should catch the 0-column case.
        # This is a safeguard.
        return(.df_orig[0L, , drop=FALSE])
      }


      match_rows_logical = apply(match_matrix, 1, function(row_of_matches) {
        any(row_of_matches, na.rm = TRUE)
      })

      return(.df_orig[match_rows_logical & !is.na(match_rows_logical), , drop = FALSE])
    }
  }
  return(search_in_df)
}
