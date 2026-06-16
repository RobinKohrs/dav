# UN OCHA Casualties – Power BI Data Extraction
# ==============================================================================
# Source: https://www.ochaopt.org/data/casualties
# Methodology: reverse-engineered POST requests to the Power BI backend API
# that serves the embedded dashboards on that page.
#
# All ResourceKeys, DatasetIds, ReportIds, modelIds, entity names, column names,
# filter requirements, and aggregation functions were verified from live
# browser DevTools network captures.

# ── Filter helpers ─────────────────────────────────────────────────────────────

# Date range filter: col >= from_date AND col <= to_date.
# ComparisonKind: 2 = GreaterThanOrEqual, 3 = LessThanOrEqual.
ocha_make_date_filter <- function(src, col, from_date, to_date) {
  list(Condition = list(And = list(
    Left = list(Comparison = list(
      ComparisonKind = 2L,
      Left  = list(Column = list(
        Expression = list(SourceRef = list(Source = src)),
        Property   = col
      )),
      Right = list(Literal = list(
        Value = paste0("datetime'", from_date, "T00:00:00'")
      ))
    )),
    Right = list(Comparison = list(
      ComparisonKind = 3L,
      Left  = list(Column = list(
        Expression = list(SourceRef = list(Source = src)),
        Property   = col
      )),
      Right = list(Literal = list(
        Value = paste0("datetime'", to_date, "T00:00:00'")
      ))
    ))
  )))
}

# Categorical IN filter: col IN (values).
ocha_make_in_filter <- function(src, col, values) {
  list(Condition = list(In = list(
    Expressions = list(list(Column = list(
      Expression = list(SourceRef = list(Source = src)),
      Property   = col
    ))),
    Values = lapply(values, function(v) {
      list(list(Literal = list(Value = paste0("'", v, "'"))))
    })
  )))
}

# NOT IN null guard: excludes rows where col IS NULL.
# Required for "Hostilities" on vw_BS_Pal_Fatalities.
# Also used as the standard guard in fetch-distinct-values queries.
ocha_make_not_null_filter <- function(src, col) {
  list(Condition = list(Not = list(
    Expression = list(In = list(
      Expressions = list(list(Column = list(
        Expression = list(SourceRef = list(Source = src)),
        Property   = col
      ))),
      Values = list(list(list(Literal = list(Value = "null"))))
    ))
  )))
}

# ── Payload builder ────────────────────────────────────────────────────────────

# Builds a Power BI SemanticQueryDataShapeCommand payload for a by-region
# aggregation query.
#
# entity         View/table name in the Power BI data model.
# region_col     Dimension column for the group-by.  NULL = total-only query
#                (no group-by; returns a single-row aggregate).
# count_col      Measure column name.
# dataset_id     ApplicationContext DatasetId.
# report_id      ApplicationContext ReportId.
# model_id       Top-level modelId.
# src            Source alias used in From / SourceRef ("v1" or "v").
# count_fn       Aggregation function: 0 = Sum, 5 = CountNonNull.
# region_alias   Display name override for region_col.  NULL defaults to
#                "entity.region_col".  Use for the "Area" -> "Region" alias
#                quirk in vw_BS_Pal_Fatalities.
# data_reduction "top" (default) or "window".  Use "window" for datasets with
#                Window{Count:1000} pagination (confirmed: isr_injuries).
# window_count   Rows per page when data_reduction = "window" (default 1000).
# where_filters      List of filter conditions from ocha_make_*_filter().
# restart_token      Opaque pagination token from a previous response; NULL on
#                    first call.  Only relevant for "window" queries.
# sort_desc_by_count If TRUE (default), OrderBy sorts descending by the count
#                    aggregation.  Set FALSE to sort ascending by region_col
#                    (use for date/time-series grouping).
ocha_build_payload <- function(
    entity, region_col, count_col,
    dataset_id, report_id, model_id,
    src                = "v1",
    count_fn           = 0L,
    region_alias       = NULL,
    data_reduction     = "top",
    data_volume        = 4L,
    window_count       = 1000L,
    where_filters      = list(),
    restart_token      = NULL,
    sort_desc_by_count = TRUE
) {
  count_prefix <- if (count_fn == 0L) "Sum" else "CountNonNull"
  count_name   <- paste0(count_prefix, "(", entity, ".", count_col, ")")

  select_cols <- list()
  if (!is.null(region_col)) {
    if (is.null(region_alias)) region_alias <- paste0(entity, ".", region_col)
    select_cols <- c(select_cols, list(
      list(
        Column = list(
          Expression = list(SourceRef = list(Source = src)),
          Property   = region_col
        ),
        Name = region_alias
      )
    ))
  }
  select_cols <- c(select_cols, list(
    list(
      Aggregation = list(
        Expression = list(
          Column = list(
            Expression = list(SourceRef = list(Source = src)),
            Property   = count_col
          )
        ),
        Function = count_fn
      ),
      Name = count_name
    )
  ))

  order_by <- if (!is.null(region_col)) {
    if (sort_desc_by_count) {
      # Default: descending by count (highest first) — for region/weapon groupings
      list(list(
        Direction = 2L,
        Expression = list(
          Aggregation = list(
            Expression = list(
              Column = list(
                Expression = list(SourceRef = list(Source = src)),
                Property   = count_col
              )
            ),
            Function = count_fn
          )
        )
      ))
    } else {
      # Ascending by the grouping column — for date/time-series queries
      list(list(
        Direction = 1L,
        Expression = list(
          Column = list(
            Expression = list(SourceRef = list(Source = src)),
            Property   = region_col
          )
        )
      ))
    }
  } else {
    list()
  }

  if (data_reduction == "window") {
    win <- list(Count = as.integer(window_count))
    if (!is.null(restart_token)) win$RestartTokens <- list(restart_token)
    dr <- list(DataVolume = 3L, Primary = list(Window = win))
  } else {
    dr <- list(DataVolume = as.integer(data_volume), Primary = list(Top = list()))
  }

  # Projections: 0-indexed column indices.
  # Two-column grouped query: [0,1].  Total-only: scalar 0 (matches captured payloads).
  projections <- if (!is.null(region_col)) c(0L, 1L) else 0L

  query_inner <- list(
    Version = 2L,
    From    = list(list(Name = src, Entity = entity, Type = 0L)),
    Select  = select_cols
  )
  if (length(order_by)      > 0) query_inner$OrderBy <- order_by
  if (length(where_filters)  > 0) query_inner$Where  <- where_filters

  list(
    version = "1.0.0",
    queries = list(list(
      Query = list(
        Commands = list(list(
          SemanticQueryDataShapeCommand = list(
            Query = query_inner,
            Binding = list(
              Primary       = list(Groupings = list(list(Projections = projections))),
              DataReduction = dr,
              Version       = 1L
            )
          )
        ))
      ),
      QueryId            = "",
      ApplicationContext = list(
        DatasetId = dataset_id,
        Sources   = list(list(ReportId = report_id))
      )
    )),
    cancelQueries = list(),
    modelId       = model_id
  )
}

# Internal: parse Power BI DSR (Data Shape Result) sparse row format.
#
# Power BI uses run-length encoding in its response: if a column value repeats
# from the previous row, the R bitmask has the corresponding bit set and the
# value is omitted from the C array.  Bit i (0-indexed) in R corresponds to
# column i+1 (1-indexed in R's seq_len).
ocha_parse_dsr <- function(data_rows, column_names, ext_col_dicts = NULL) {
  if (is.null(data_rows) || length(data_rows) == 0L) {
    return(dplyr::bind_rows(list()))
  }

  n_cols <- length(column_names)
  first  <- data_rows[[1L]]

  # Flat array: each element is a bare atomic value (not a named list with keys).
  # Covers JSON like ["Gaza", "Hebron", ...] or [1, 2, 3, ...].
  if (!is.list(first) || (length(first) > 0L && is.null(names(first)))) {
    values <- unlist(data_rows, recursive = FALSE, use.names = FALSE)
    return(tibble::tibble(!!column_names[[1L]] := values))
  }

  # Pre-scan for segment descriptor rows — these carry value dictionaries for
  # integer-coded dimension columns in multi-column GROUP BY responses.
  # Segment rows have an S key but no C key (they are not data rows).
  # Expected format: {"S": [{"N": <0-based col idx>, "T": ["val0", "val1", ...]}, ...]}
  col_dicts  <- vector("list", n_cols)   # per-column string lookup tables
  data_only  <- list()

  for (row in data_rows) {
    if (!is.null(row[["S"]]) && is.null(row[["C"]])) {
      segs <- row[["S"]]
      # Normalise: a single segment object is wrapped in a list
      if (is.list(segs) && !is.null(segs[["N"]])) segs <- list(segs)
      if (is.list(segs)) {
        for (seg in segs) {
          col_zero <- seg[["N"]]
          # Try common field names for the string value array
          vals <- if (!is.null(seg[["T"]])) seg[["T"]] else
                  if (!is.null(seg[["Items"]])) seg[["Items"]] else
                  if (!is.null(seg[["V"]])) seg[["V"]] else NULL
          if (!is.null(col_zero) && !is.null(vals)) {
            idx1 <- as.integer(col_zero) + 1L
            if (idx1 >= 1L && idx1 <= n_cols)
              col_dicts[[idx1]] <- as.character(unlist(vals, use.names = FALSE))
          }
        }
      }
      # Do NOT add segment rows to data_only
    } else {
      data_only <- c(data_only, list(row))
    }
  }

  # Merge external dicts (from DS[[1]]$ValueDicts) — they take priority over
  # anything found via the in-row segment scan above.
  if (!is.null(ext_col_dicts)) {
    for (i in seq_along(ext_col_dicts)) {
      if (!is.null(ext_col_dicts[[i]])) col_dicts[[i]] <- ext_col_dicts[[i]]
    }
  }

  # Use data_only if any segment rows were found, otherwise original list
  rows_to_parse <- if (length(data_only) < length(data_rows)) data_only else data_rows

  # Standard Power BI row-wise sparse encoding: each element is a named list
  # with optional keys C (new values) and R (bitmask of repeated columns).
  prev_vals <- vector("list", n_cols)

  parsed <- lapply(rows_to_parse, function(row) {
    c_vals <- if (!is.null(row[["C"]])) {
      row[["C"]]
    } else {
      # Non-aggregated distinct-value queries use G0, G1, ... instead of C.
      # G<n> holds the value for the n-th grouped column; sort numerically so
      # multi-column results stay in the right order.
      g_keys <- grep("^G[0-9]+$", names(row), value = TRUE)
      if (length(g_keys) > 0L) {
        g_keys <- g_keys[order(as.integer(sub("^G", "", g_keys)))]
        lapply(g_keys, function(k) row[[k]])
      } else {
        list()
      }
    }
    r_mask <- if (!is.null(row[["R"]])) as.integer(row[["R"]]) else 0L

    current <- prev_vals
    ci      <- 1L

    for (i in seq_len(n_cols)) {
      if (bitwAnd(r_mask, bitwShiftL(1L, i - 1L)) == 0L) {
        raw_val <- if (ci <= length(c_vals)) c_vals[[ci]] else NA
        # Resolve integer code to text via value dictionary if available
        current[[i]] <- if (!is.null(col_dicts[[i]]) &&
                            is.numeric(raw_val) && !is.na(raw_val)) {
          idx1 <- as.integer(raw_val) + 1L
          if (idx1 >= 1L && idx1 <= length(col_dicts[[i]])) col_dicts[[i]][[idx1]] else raw_val
        } else {
          raw_val
        }
        ci <- ci + 1L
      }
    }

    prev_vals <<- current
    stats::setNames(current, column_names)
  })

  result <- dplyr::bind_rows(parsed)

  # Diagnostic: if every cell is NA the DSR row format is something we haven't
  # seen before.  Emit a warning with the actual row keys so we can extend the
  # parser.
  if (nrow(result) > 0L &&
      all(vapply(result, function(x) all(is.na(x)), logical(1L)))) {
    sample_keys <- unique(unlist(
      lapply(data_rows[seq_len(min(3L, length(data_rows)))], names)
    ))
    warning(
      "ocha_parse_dsr: all values are NA \u2014 unknown DSR row format.\n",
      "  Keys found in first few rows: ",
      if (length(sample_keys)) paste(sample_keys, collapse = ", ") else "(none — all rows are empty {})",
      call. = FALSE
    )
  }

  result
}

# POSTs to the Power BI API and returns a tidy tibble.
# Automatically follows RestartToken pagination for Window-type queries.
# Each page is parsed independently (sparse encoding does not carry across pages).
ocha_fetch_powerbi <- function(resource_key, payload, debug_dsr = FALSE) {
  api_url   <- "https://wabi-north-europe-j-primary-api.analysis.windows.net/public/reports/querydata?synchronous=true"
  col_names     <- NULL
  ext_col_dicts <- NULL
  pages         <- list()

  repeat {
    # Serialize manually so auto_unbox is guaranteed and Content-Type is not
    # duplicated by httr's encode argument.
    body_json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")

    resp <- httr::POST(
      url  = api_url,
      body = body_json,
      config = httr::add_headers(
        "Content-Type"          = "application/json;charset=UTF-8",
        "X-PowerBI-ResourceKey" = resource_key,
        "Accept"                = "application/json, text/plain, */*",
        # RequestId is expected by Power BI; a random hex string is sufficient.
        "RequestId" = paste(sample(c(as.character(0:9), letters[1:6]),
                                   32L, replace = TRUE), collapse = "")
      )
    )

    status <- httr::status_code(resp)

    # Power BI returns 401 for an invalid/revoked key in most cases, but some
    # embed configurations return 400 when the resource key is expired.
    # Treat both as a retriable auth failure so the auto-refresh logic fires.
    if (status %in% c(400L, 401L)) {
      cond <- structure(
        class = c("ocha_401_error", "error", "condition"),
        list(message = sprintf(
          "HTTP %d \u2013 resource key expired or revoked (or malformed payload)",
          status
        ))
      )
      stop(cond)
    }
    httr::stop_for_status(resp)

    parsed      <- jsonlite::fromJSON(
      httr::content(resp, "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
    data_result <- parsed$results[[1]]$result$data
    ds          <- data_result$dsr$DS[[1]]
    ph          <- ds$PH[[1]]

    # Debug: print DSR structure keys to help locate value dictionaries.
    if (debug_dsr) {
      message("=== DSR debug (first page only) ===")
      message("dsr keys:       ", paste(names(data_result$dsr),        collapse = ", "))
      message("DS[[1]] keys:   ", paste(names(ds),                      collapse = ", "))
      message("PH[[1]] keys:   ", paste(names(ph),                      collapse = ", "))
      message("DM0 row count:  ", length(ph$DM0))
      # Print any error/warning indicators in the response
      err_node <- parsed$results[[1]]$result$error
      if (!is.null(err_node)) message("result$error:   ", utils::str(err_node))
      ds_no_ph <- ds[setdiff(names(ds), "PH")]
      if (length(ds_no_ph)) message(utils::str(ds_no_ph, max.level = 3))
      if (length(ph$DM0) > 0L && length(ph$DM0) <= 3L)
        message("DM0 sample:     ", utils::str(ph$DM0, max.level = 4))
      debug_dsr <- FALSE  # only print once
    }

    # Extract column names from the descriptor on the first response only.
    # Handles these Name patterns from the Select clause:
    #   "entity.Column (groups)"                  -> "Column (groups)"
    #   "Sum(entity.Fat)"                         -> "Fat"
    #   "CountNonNull(entity.Fatalities)"         -> "Fatalities"
    #   "Region"  (alias without entity prefix)   -> "Region"
    if (is.null(col_names)) {
      descriptor <- data_result$descriptor$Select
      col_names  <- vapply(descriptor, function(x) {
        nm <- x$Name
        # Strip aggregation wrapper Sum(...) / CountNonNull(...) as one unit,
        # so the trailing ) is only removed when there is a matching opening
        # function call — not from bare column names like "Govornorate (groups)".
        nm <- sub("^(?:Sum|CountNonNull)\\((.+)\\)$", "\\1", nm)
        nm <- sub("^[^.]+\\.",             "", nm)   # strip "Entity." prefix
        nm
      }, character(1))

      # Extract ValueDicts from DS[[1]]$ValueDicts if present.
      # Power BI encodes string dimension columns as 0-based integer indices into
      # per-column lookup tables D0, D1, ....  In our queries, select position 0
      # is always Date (no dict), so D0 -> R column 2, D1 -> R column 3, etc.
      vd <- ds$ValueDicts
      if (!is.null(vd) && length(vd) > 0L) {
        n <- length(col_names)
        ext_col_dicts <- vector("list", n)
        for (di in seq_along(vd)) {
          d <- vd[[paste0("D", di - 1L)]]
          r_idx <- di + 1L  # D0 -> R index 2, D1 -> R index 3, ...
          if (!is.null(d) && r_idx <= n) {
            ext_col_dicts[[r_idx]] <- as.character(unlist(d, use.names = FALSE))
          }
        }
      }
    }

    data_rows     <- ph$DM0
    restart_token <- ph$Restart

    if (!is.null(data_rows) && length(data_rows) > 0L) {
      pages <- c(pages, list(ocha_parse_dsr(data_rows, col_names,
                                            ext_col_dicts = ext_col_dicts)))
    }

    if (is.null(restart_token)) break

    # Inject restart token into the payload for the next page
    payload$queries[[1]]$Query$Commands[[1]]$
      SemanticQueryDataShapeCommand$Binding$
      DataReduction$Primary$Window$RestartTokens <- list(restart_token)
  }

  # Power BI can return dimension columns as integer keys on pages where every
  # value happens to be NULL/NA, but as character strings on other pages.
  # Harmonize any such mixed-type columns to character before combining.
  if (length(pages) > 1L) {
    col_type_sets <- lapply(names(pages[[1L]]), function(cn) {
      unique(vapply(pages, function(p) class(p[[cn]])[[1L]], character(1L)))
    })
    names(col_type_sets) <- names(pages[[1L]])
    mixed <- names(Filter(function(t) length(t) > 1L, col_type_sets))
    if (length(mixed) > 0L) {
      pages <- lapply(pages, function(p) {
        for (cn in mixed) p[[cn]] <- as.character(p[[cn]])
        p
      })
    }
  }

  dplyr::bind_rows(pages)
}

# ==============================================================================

#' Fetch casualty data from UN OCHA's Protection of Civilians database
#'
#' Queries fatality and injury counts broken down by region for Palestinians
#' and Israelis from the Power BI dashboards embedded on
#' \url{https://www.ochaopt.org/data/casualties}. Data covers occupation- and
#' conflict-related incidents in the occupied Palestinian territory (OPT) and
#' Israel since 2008.
#'
#' @details
#' \strong{Data source:}
#' The underlying data comes from OCHA's Protection of Civilians (POC) database.
#' Incidents are independently verified by OCHA field staff and require at least
#' two independent, reliable sources before entry.
#'
#' \strong{Coverage note:}
#' Casualties from the Gaza hostilities that began on 7 October 2023 are
#' \emph{not} included here; those figures appear in OCHA's Humanitarian
#' Situation Updates.
#'
#' \strong{Implementation notes:}
#' Data is retrieved by replicating POST requests to the Power BI backend API
#' (\code{wabi-north-europe-j-primary-api.analysis.windows.net}).  Each of the
#' four dashboards requires a distinct \code{X-PowerBI-ResourceKey} header.
#'
#' \strong{Dataset-specific notes:}
#' \itemize{
#'   \item \strong{pal_fatalities} — grouped by governorate (note:
#'     \code{"Govornorate"} is the actual spelling in OCHA's data model, not a
#'     typo here). A NOT IN null guard on \code{Hostilities} is always applied;
#'     omitting it returns different totals.
#'   \item \strong{isr_fatalities} — uses \code{CountNonNull} aggregation on
#'     \code{Fatalities}. Group by \code{"Region"} (Area) returns totals for
#'     Gaza Strip, West Bank, Israel. Also supports grouping by \code{"Date"},
#'     \code{"SA (groups)"}, \code{"Govornorate (groups)"}, and filtering by
#'     \code{"victim_affiliation (groups) 2"} (e.g., \code{"Israeli Civilians"},
#'     \code{"Security forces"}, \code{"Civilian-settler"}).
#'   \item \strong{pal_injuries} — a \code{Poc_Period IN ('yes', 'Yes')} filter
#'     is always applied; omitting it returns a different total. The date column
#'     in this view is \code{"Date:"} (with a trailing colon — real data model
#'     quirk). Sanity-check total: 165,765.
#'   \item \strong{isr_injuries} — grouped by \code{Community}. Uses
#'     Window-based pagination (1,000 rows/page with RestartToken). Uses
#'     \code{CountNonNull}. The measure column name contains a trailing space
#'     (\code{"Injuries "}) — this is the real data model name.
#'     Sanity-check total: 6,697.
#' }
#'
#' @param type Character. Which dataset to retrieve. One of:
#'   \describe{
#'     \item{\code{"all"} (default)}{Returns a named list containing all four
#'       tibbles. Failed sub-queries return \code{NULL} with a warning.}
#'     \item{\code{"pal_fatalities"}}{Palestinian fatalities by governorate.}
#'     \item{\code{"isr_fatalities"}}{Israeli fatalities by area.}
#'     \item{\code{"pal_injuries"}}{Palestinian injuries by governorate.}
#'     \item{\code{"isr_injuries"}}{Israeli injuries by area.}
#'   }
#'
#' @return A tibble (for a single \code{type}) or a named list of tibbles
#'   (for \code{type = "all"}).  Each tibble has two columns: the region name
#'   and the aggregate count, ordered descending by count.
#'
#' @examples
#' \dontrun{
#' # Palestinian fatalities by governorate (default)
#' pal_fat <- un_ocha_fatalities("pal_fatalities")
#'
#' # Palestinian fatalities over time
#' pal_fat_ts <- un_ocha_fatalities("pal_fatalities", group_by = "Date")
#'
#' # By weapon type
#' pal_fat_weapon <- un_ocha_fatalities("pal_fatalities", group_by = "Weapon_name (groups)")
#'
#' # All four datasets at once
#' all_data <- un_ocha_fatalities("all")
#' }
#'
#' @param region Optional character vector of region/governorate names to
#'   **include**.  Applied as an IN-filter on the dataset's region column
#'   (e.g. \code{"Govornorate (groups)"} for Palestinian datasets).  Use
#'   \code{\link{un_ocha_fetch_filter_values}} to discover the exact strings
#'   accepted by the data model.  Ignored for datasets that have no region
#'   column (\code{isr_fatalities}).  Cannot be used with
#'   \code{type = "all"}.
#'
#' @param area Optional character vector for quick geographic subsetting of
#'   Palestinian datasets.  One or more of \code{"west_bank"},
#'   \code{"israel"}, \code{"gaza"}.  Expands to the corresponding set of
#'   OCHA governorate names and is applied as an IN-filter on
#'   \code{"Govornorate (groups)"}.  Can be combined with \code{region} or
#'   \code{filters}; the resulting filter is the union of all specified
#'   governorates.  Silently ignored for \code{isr_fatalities} and
#'   \code{isr_injuries} (which use a different region dimension).
#'   Cannot be used with \code{type = "all"}.
#'
#' @seealso \code{\link{un_ocha_fetch_filter_values}} to discover the exact
#'   string values available for any filterable column.
#'
#' @export
#' @importFrom httr POST add_headers stop_for_status content
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning
un_ocha_fatalities <- function(
    type     = c("all", "pal_fatalities", "isr_fatalities",
                 "pal_injuries",  "isr_injuries"),
    group_by = NULL,
    region   = NULL,
    filters  = NULL,
    area     = NULL
) {
  type <- match.arg(type)

  if (!is.null(group_by) && type == "all") {
    stop('`group_by` cannot be used with type = "all". Choose a specific dataset.')
  }
  if (!is.null(region) && type == "all") {
    stop('`region` cannot be used with type = "all". Choose a specific dataset.')
  }
  if (!is.null(filters) && type == "all") {
    stop('`filters` cannot be used with type = "all". Choose a specific dataset.')
  }
  if (!is.null(area) && type == "all") {
    stop('`area` cannot be used with type = "all". Choose a specific dataset.')
  }

  # Governorate subsets for the convenience `area` parameter.
  # Covers pal_fatalities and pal_injuries ("Govornorate (groups)" column).
  # "Not listed" is grouped under west_bank as OCHA typically uses it for
  # West Bank incidents without a specific governorate attribution.
  .area_govs <- list(
    west_bank = c("Bethlehem", "Hebron", "Jenin", "Jericho", "Jerusalem",
                  "Nablus", "Not listed", "Qalqiliya", "Ramallah",
                  "Salfit", "Tubas", "Tulkarm"),
    israel    = "Israel",
    gaza      = c("Deir Al-Balah", "Gaza", "Khan Younis", "North Gaza", "Rafah")
  )

  if (!is.null(area)) {
    unknown_areas <- setdiff(area, names(.area_govs))
    if (length(unknown_areas) > 0L) {
      stop(
        'Unknown area value(s): ', paste(unknown_areas, collapse = ", "),
        '. Use "west_bank", "israel", and/or "gaza".'
      )
    }
  }

  # ── Per-dataset configuration (all fields verified from DevTools captures) ──
  #
  # key        X-PowerBI-ResourceKey header value
  # entity     View/table name in the Power BI data model
  # src        Source alias used in From / SourceRef clauses ("v" or "v1")
  # region_col Dimension column for group-by; NULL = total-only (returns one row)
  # count_col  Measure column name (may contain trailing space — intentional)
  # count_fn   0 = Sum, 5 = CountNonNull
  # dr         DataReduction type: "top" or "window"
  # filters    Where conditions; some datasets require specific filters always
  # dataset_id / report_id / model_id  ApplicationContext identifiers
  configs <- list(

    pal_fatalities = list(
      label       = "Palestinian Fatalities",
      key         = "60eca1ef-5852-4807-9bc3-4fdb8915c71c",
      entity      = "vw_BS_Pal_Fatalities",
      src         = "v",
      # Other confirmed groupings for this entity:
      #   "Area"                  (region_alias = "Region")
      #   "SA (groups)"           sub-area, Top{}
      #   "Community"             Window{Count:1000}
      #   "Weapon_name (groups)"  Window{Count:1000}
      region_col  = "Govornorate (groups)",  # typo matches the real data model
      count_col   = "Fat",
      count_fn    = 0L,
      dr          = "window",
      data_volume = 4L,
      filters     = list(
        ocha_make_not_null_filter("v", "Hostilities")  # always required
      ),
      dataset_id  = "6837d825-7b35-486b-83b4-d8ffc90325f0",
      report_id   = "ab42e258-22eb-4acc-8b6f-6cb117f95baa",
      model_id    = 1272287L
    ),

    isr_fatalities = list(
      label       = "Israeli Fatalities",
      key         = "e167c357-daaa-42bd-aa73-e539ee14a2d4",
      entity      = "vw_BS_Isr_Fatalities",
      src         = "v1",
      region_col  = "Region",
      count_col   = "Fatalities",
      count_fn    = 5L,       # CountNonNull
      dr          = "window",
      data_volume = 3L,
      filters     = list(),
      dataset_id  = "c1523f44-2968-4e6a-979a-5bb84a1f4cde",
      report_id   = "c8856647-e870-4856-befa-0f9087f8e236",
      model_id    = 1300830L
    ),

    pal_injuries = list(
      label       = "Palestinian Injuries",
      key         = "d65f26ab-1d4c-4c33-a5e0-8a4afe12ce1c",
      entity      = "vw_BS_Pal_Injuries",
      src         = "v1",
      region_col  = "Govornorate (groups)",
      count_col   = "Inj",
      count_fn    = 0L,
      dr          = "window",
      data_volume = 4L,
      # Poc_Period filter is always required; omitting it changes totals.
      # Date column for this entity is "Date:" (trailing colon — real model quirk).
      filters     = list(
        ocha_make_in_filter("v1", "Poc_Period", c("yes", "Yes"))
      ),
      dataset_id  = "b9ab430a-525d-4bc8-8397-e0edd45cd453",
      report_id   = "46625751-da8a-42a6-a3e8-d4a3f1a4d570",
      model_id    = 1272286L
    ),

    isr_injuries = list(
      label       = "Israeli Injuries",
      key         = "ebeb5c54-2c96-4a9c-b913-6a7a8ccf8c00",
      entity      = "vw_BS_Isr_Injuries",
      src         = "v",
      region_col  = "Community",
      count_col   = "Injuries ",  # trailing space is intentional — real model name
      count_fn    = 5L,           # CountNonNull
      dr          = "window",     # Window{Count:1000} — different from others
      data_volume = 3L,           # window branch always uses DataVolume = 3
      filters     = list(),
      dataset_id  = "5bd7183c-420b-4727-b350-298104f4d4e7",
      report_id   = "71f0e246-4767-41d7-882a-9c228a537cdc",
      model_id    = 1272285L
    )

  )

  targets <- if (type == "all") names(configs) else type

  results <- lapply(targets, function(nm) {
    cfg <- configs[[nm]]

    # group_by overrides the per-dataset default region column.
    # Date columns produce ascending chronological order and use Window pagination
    # to ensure all dates are retrieved regardless of how many rows exist.
    effective_region <- if (!is.null(group_by)) group_by else cfg$region_col
    is_date_group    <- !is.null(group_by) && grepl("date", group_by, ignore.case = TRUE)
    effective_dr     <- if (is_date_group) "window" else cfg$dr

    # For date-series queries the per-dataset region filters (e.g. the
    # Hostilities NOT NULL guard for pal_fatalities) are NOT applied.
    # Those filters are tailored for the governorate view and exclude rows
    # that are valid for time-series aggregation (e.g. incidents entered
    # without a Hostilities classification).  For date queries we want the
    # unfiltered measure so the series matches what the website shows.
    effective_filters <- if (is_date_group) list() else cfg$filters

    # Optional region IN-filter — restricts to specific governorates/areas
    # while keeping the group_by column as-is.  Applied on cfg$region_col
    # (not on the grouping column), so it works for both regional and date views.
    if (!is.null(region) && !is.null(cfg$region_col)) {
      effective_filters <- c(
        effective_filters,
        list(ocha_make_in_filter(cfg$src, cfg$region_col, region))
      )
    }

    # Convenience area filter: expand named areas to governorate lists.
    # Only applied when the dataset has a Govornorate (groups) region column.
    if (!is.null(area) && !is.null(cfg$region_col)) {
      area_govs <- unique(unlist(.area_govs[area], use.names = FALSE))
      effective_filters <- c(
        effective_filters,
        list(ocha_make_in_filter(cfg$src, cfg$region_col, area_govs))
      )
    }

    # Arbitrary column filters: named list of col = values pairs.
    # Useful for filtering by Area, Year, Weapon, etc. alongside group_by.
    # Example: filters = list("Area" = "West Bank", "Year" = c(2023, 2024))
    if (!is.null(filters)) {
      for (col_name in names(filters)) {
        effective_filters <- c(
          effective_filters,
          list(ocha_make_in_filter(cfg$src, col_name,
                                   as.character(filters[[col_name]])))
        )
      }
    }

    payload <- ocha_build_payload(
      entity             = cfg$entity,
      region_col         = effective_region,
      count_col          = cfg$count_col,
      dataset_id         = cfg$dataset_id,
      report_id          = cfg$report_id,
      model_id           = cfg$model_id,
      src                = cfg$src,
      count_fn           = cfg$count_fn,
      data_reduction     = effective_dr,
      data_volume        = cfg$data_volume,
      window_count       = if (is_date_group) 5000L else 1000L,
      where_filters      = effective_filters,
      sort_desc_by_count = !is_date_group
    )

    # Attempt up to twice: first with the stored key, then with a freshly
    # scraped key (auto-refresh on HTTP 401).
    effective_key <- cfg$key

    for (attempt in seq_len(2L)) {
      cli::cli_alert_info("Fetching {cfg$label} from UN OCHA...")

      df_out <- tryCatch(
        ocha_fetch_powerbi(effective_key, payload),
        ocha_401_error = function(e) {
          if (attempt == 1L) {
            cli::cli_alert_warning(
              "Resource key stale for {cfg$label} \u2014 attempting auto-refresh..."
            )
            fresh <- tryCatch(
              un_ocha_get_resource_keys(),
              error = function(ke) NULL
            )
            if (!is.null(fresh) && !is.na(fresh[[nm]])) {
              effective_key <<- fresh[[nm]]
              return(NULL)  # NULL = retry the loop
            }
          }
          structure(list(msg = conditionMessage(e)), class = "ocha_fetch_err")
        },
        error = function(e) {
          structure(list(msg = conditionMessage(e)), class = "ocha_fetch_err")
        }
      )

      if (inherits(df_out, "ocha_fetch_err")) {
        cli::cli_alert_warning(
          "Could not fetch {cfg$label}: {df_out$msg}"
        )
        return(NULL)  # permanent failure
      }
      if (!is.null(df_out)) {
        # Power BI encodes dates as Unix timestamps in milliseconds.
        # Convert to R Date when the group-by column is a date column.
        if (is_date_group && nrow(df_out) > 0L) {
          date_col <- names(df_out)[[1L]]
          df_out[[date_col]] <- as.Date(
            as.POSIXct(as.numeric(df_out[[date_col]]) / 1000,
                       origin = "1970-01-01", tz = "UTC")
          )
        }
        cli::cli_alert_success("Retrieved {nrow(df_out)} rows for {cfg$label}.")
        return(df_out)
      }
      # NULL means retry with refreshed key
    }
    NULL
  })

  names(results) <- targets
  if (type != "all") return(results[[type]])
  results
}

#' Fetch all OCHA casualty records with every available categorical dimension
#'
#' Returns a flat tibble with one row per unique combination of categorical
#' dimensions (Date, Area, Governorate, perpetrator affiliation, nationality,
#' etc.) plus the total count for that combination.  Use this when you want to
#' filter and aggregate the data yourself instead of relying on server-side
#' grouping.
#'
#' @param type Character.  One of \code{"pal_fatalities"},
#'   \code{"pal_injuries"}, \code{"isr_fatalities"}, \code{"isr_injuries"}.
#' @param filters Named list of additional column → value(s) filters,
#'   identical to the \code{filters} argument of
#'   \code{\link{un_ocha_fatalities}}.
#'
#' @return A tibble.  The exact columns depend on \code{type}.  \code{Date} is
#'   always an R \code{Date}.  The count column is named after the underlying
#'   measure (\code{Fat}, \code{Inj}, \code{Fatalities}, \code{Injuries}).
#'
#' @examples
#' \dontrun{
#' all_pal_fat  <- un_ocha_fatalities_all("pal_fatalities")
#' all_pal_inj  <- un_ocha_fatalities_all("pal_injuries")
#' all_isr_fat  <- un_ocha_fatalities_all("isr_fatalities")
#' all_isr_inj  <- un_ocha_fatalities_all("isr_injuries")
#'
#' # Filter yourself after fetching
#' all_pal_fat |>
#'   dplyr::filter(Area == "West Bank", `Doer Aff. (groups)` == "Civilian-settler")
#' }
#' @export
un_ocha_fatalities_all <- function(type = "pal_fatalities", filters = NULL,
                                   date_range = NULL,
                                   debug_dsr = FALSE) {
  meta <- list(

    pal_fatalities = list(
      label       = "Palestinian Fatalities",
      key         = "60eca1ef-5852-4807-9bc3-4fdb8915c71c",
      entity      = "vw_BS_Pal_Fatalities",
      src         = "v",
      group_cols  = c("Date", "Area", "Govornorate (groups)", "Community",
              "Doer Aff. (groups)", "doer nat", "Weapon_name (groups)",
              "Sex", "Child/Adult", "Hostilities", "Context",
              "Type of incident ", "Victim Aff. (groups)", "SA (groups)"),
      count_col   = "Fat",
      count_fn    = 0L,
      date_col    = "Date",
      req_filters = list(),
      dataset_id  = "6837d825-7b35-486b-83b4-d8ffc90325f0",
      report_id   = "ab42e258-22eb-4acc-8b6f-6cb117f95baa",
      model_id    = 1272287L
    ),

    pal_injuries = list(
      label       = "Palestinian Injuries",
      key         = "d65f26ab-1d4c-4c33-a5e0-8a4afe12ce1c",
      entity      = "vw_BS_Pal_Injuries",
      src         = "v1",
      # Note: date column in this entity has a trailing colon — real data model quirk.
      group_cols  = c("Date:", "Area", "Govornorate (groups)",
                      "Doer Aff. (groups)", "doer nat"),
      count_col   = "Inj",
      count_fn    = 0L,
      date_col    = "Date:",
      req_filters = list(
        ocha_make_in_filter("v1", "Poc_Period", c("yes", "Yes"))
      ),
      # The Date: column requires an explicit date range filter or the API
      # returns an empty result set (no error, just zero rows).
      default_date_range = c("2008-01-01", format(Sys.Date(), "%Y-%m-%d")),
      dataset_id  = "b9ab430a-525d-4bc8-8397-e0edd45cd453",
      report_id   = "46625751-da8a-42a6-a3e8-d4a3f1a4d570",
      model_id    = 1272286L
    ),

    isr_fatalities = list(
      label       = "Israeli Fatalities",
      key         = "e167c357-daaa-42bd-aa73-e539ee14a2d4",
      entity      = "vw_BS_Isr_Fatalities",
      src         = "v1",
      group_cols  = c("Date", "Region", "Govornorate", "Govornorate (groups)", "Community",
                        "victim_affiliation (groups) 2", "victim_affiliation (groups)",
                        "victim_affiliation (groups) 3", "victim_affiliation",
                        "doer_affiliation (groups)", "doer_affiliation",
                        "victim nat", "doer nat",
                        "Sex", "Child_Ind", "Weapon_name",
                        "Type of incident", "Context_Name", "Sub_Type", "Type",
                        "Hostilities", "SA (groups)", "Poc_Period"),
      count_col   = "Fatalities",
      count_fn    = 5L,         # CountNonNull
      date_col    = "Date",
      req_filters = list(),
      dataset_id  = "c1523f44-2968-4e6a-979a-5bb84a1f4cde",
      report_id   = "c8856647-e870-4856-befa-0f9087f8e236",
      model_id    = 1300830L
    ),

    isr_injuries = list(
      label       = "Israeli Injuries",
      key         = "ebeb5c54-2c96-4a9c-b913-6a7a8ccf8c00",
      entity      = "vw_BS_Isr_Injuries",
      src         = "v",
      group_cols  = c("Date", "Community"),
      count_col   = "Injuries ",  # trailing space is intentional — real model name
      count_fn    = 5L,           # CountNonNull
      date_col    = "Date",
      req_filters = list(),
      dataset_id  = "5bd7183c-420b-4727-b350-298104f4d4e7",
      report_id   = "71f0e246-4767-41d7-882a-9c228a537cdc",
      model_id    = 1272285L
    )

  )

  cfg <- meta[[type]]
  if (is.null(cfg)) {
    cli::cli_abort(c(
      "Unsupported type: {.val {type}}.",
      "i" = "Choose one of: {.val {names(meta)}}."
    ))
  }

  # Build Select list: one Column entry per group col, then the count measure.
  select_list <- lapply(cfg$group_cols, function(col) {
    list(
      Column = list(
        Expression = list(SourceRef = list(Source = cfg$src)),
        Property   = col
      ),
      Name = paste0(cfg$entity, ".", col)
    )
  })
  count_prefix <- if (cfg$count_fn == 0L) "Sum" else "CountNonNull"
  count_name   <- paste0(count_prefix, "(", cfg$entity, ".", cfg$count_col, ")")
  select_list  <- c(select_list, list(list(
    Aggregation = list(
      Expression = list(
        Column = list(
          Expression = list(SourceRef = list(Source = cfg$src)),
          Property   = cfg$count_col
        )
      ),
      Function = cfg$count_fn
    ),
    Name = count_name
  )))

  # Projections: all columns 0-indexed
  projections <- as.list(seq_along(select_list) - 1L)

  # Sort ascending by Date (first Select column)
  order_by <- list(list(
    Direction = 1L,
    Expression = list(
      Column = list(
        Expression = list(SourceRef = list(Source = cfg$src)),
        Property   = cfg$group_cols[[1L]]
      )
    )
  ))

  # Arbitrary user filters combined with any dataset-required filters
  where_filters <- cfg$req_filters
  if (!is.null(filters)) {
    for (col_name in names(filters)) {
      where_filters <- c(
        where_filters,
        list(ocha_make_in_filter(cfg$src, col_name, as.character(filters[[col_name]])))
      )
    }
  }

  # Apply date range filter: user-supplied date_range takes priority,
  # then default_date_range from the dataset config (needed for pal_injuries
  # where selecting the Date: column without a date filter returns 0 rows).
  effective_date_range <- if (!is.null(date_range)) date_range else cfg$default_date_range
  if (!is.null(effective_date_range)) {
    where_filters <- c(where_filters,
      list(ocha_make_date_filter(cfg$src, cfg$date_col,
                                 effective_date_range[[1L]],
                                 effective_date_range[[2L]]))
    )
  }

  query_inner <- list(
    Version = 2L,
    From    = list(list(Name = cfg$src, Entity = cfg$entity, Type = 0L)),
    Select  = select_list,
    OrderBy = order_by
  )
  if (length(where_filters) > 0L) query_inner$Where <- where_filters

  build_payload <- function(restart_token = NULL) {
    win <- list(Count = 10000L)
    if (!is.null(restart_token)) win$RestartTokens <- list(restart_token)
    list(
      version = "1.0.0",
      queries = list(list(
        Query = list(
          Commands = list(list(
            SemanticQueryDataShapeCommand = list(
              Query   = query_inner,
              Binding = list(
                Primary       = list(Groupings = list(list(Projections = projections))),
                DataReduction = list(DataVolume = 3L, Primary = list(Window = win)),
                Version       = 1L
              )
            )
          ))
        ),
        QueryId            = "",
        ApplicationContext = list(
          DatasetId = cfg$dataset_id,
          Sources   = list(list(ReportId = cfg$report_id))
        )
      )),
      cancelQueries = list(),
      modelId       = cfg$model_id
    )
  }

  effective_key <- cfg$key

  for (attempt in seq_len(2L)) {
    cli::cli_alert_info("Fetching all {cfg$label} data from UN OCHA...")

    df_out <- tryCatch(
      ocha_fetch_powerbi(effective_key, build_payload(), debug_dsr = debug_dsr),
      ocha_401_error = function(e) {
        if (attempt == 1L) {
          cli::cli_alert_warning("Resource key stale \u2014 attempting auto-refresh...")
          fresh <- tryCatch(un_ocha_get_resource_keys(), error = function(ke) NULL)
          if (!is.null(fresh) && !is.na(fresh[[type]])) {
            effective_key <<- fresh[[type]]
            return(NULL)
          }
        }
        structure(list(msg = conditionMessage(e)), class = "ocha_fetch_err")
      },
      error = function(e) {
        structure(list(msg = conditionMessage(e)), class = "ocha_fetch_err")
      }
    )

    if (inherits(df_out, "ocha_fetch_err")) {
      cli::cli_alert_warning("Could not fetch {cfg$label}: {df_out$msg}")
      return(NULL)
    }
    if (!is.null(df_out)) {
      # Convert Unix-ms timestamp to R Date.
      # pal_injuries uses "Date:" (with trailing colon) — rename to "Date".
      if (nrow(df_out) > 0L) {
        raw_date_col <- cfg$date_col
        df_out[[raw_date_col]] <- as.Date(
          as.POSIXct(as.numeric(df_out[[raw_date_col]]) / 1000,
                     origin = "1970-01-01", tz = "UTC")
        )
        if (raw_date_col != "Date") {
          names(df_out)[names(df_out) == raw_date_col] <- "Date"
        }
      }
      cli::cli_alert_success("Retrieved {nrow(df_out)} rows.")
      return(df_out)
    }
    # NULL → retry with refreshed key
  }
  NULL
}

#' Discover the distinct values of a filterable column in an OCHA Power BI report
#'
#' Sends a "populate-dropdown" query to the Power BI API and returns all distinct
#' non-null values for the requested column.  Use this \emph{before} building
#' filtered queries to learn the exact strings to pass to the filter arguments.
#'
#' @param type Character. Which dashboard to query.  Same values as in
#'   \code{\link{un_ocha_fatalities}}, excluding \code{"all"}.
#' @param col Character. The column \emph{Property} name to fetch values for
#'   (e.g. \code{"Hostilities"}, \code{"Area"}, \code{"Weapon_name (groups)"}).
#'   Note: use the property name, not any display alias.
#'
#' @return A one-column tibble of distinct non-null values, limited to 1,000.
#'
#' @examples
#' \dontrun{
#' # What hostility-type strings exist in Palestinian Fatalities?
#' un_ocha_fetch_filter_values("pal_fatalities", "Hostilities")
#'
#' # Area values (property "Area", displayed as "Region"):
#' un_ocha_fetch_filter_values("pal_fatalities", "Area")
#'
#' # Weapon types:
#' un_ocha_fetch_filter_values("pal_fatalities", "Weapon_name (groups)")
#'
#' # Poc_Period values for Palestinian Injuries:
#' un_ocha_fetch_filter_values("pal_injuries", "Poc_Period")
#' }
#'
#' @export
#' @importFrom httr POST add_headers stop_for_status content
#' @importFrom jsonlite fromJSON
#' @importFrom dplyr bind_rows
un_ocha_fetch_filter_values <- function(
    type = c("pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries"),
    col
) {
  type <- match.arg(type)

  # Compact metadata table — mirrors the configs in un_ocha_fatalities()
  # filters: required WHERE conditions enforced for ALL queries on this dataset
  meta <- list(
    pal_fatalities = list(
      key = "60eca1ef-5852-4807-9bc3-4fdb8915c71c", entity = "vw_BS_Pal_Fatalities",
      src = "v",  dataset_id = "6837d825-7b35-486b-83b4-d8ffc90325f0",
      report_id = "ab42e258-22eb-4acc-8b6f-6cb117f95baa", model_id = 1272287L,
      filters = list(ocha_make_not_null_filter("v", "Hostilities"))
    ),
    isr_fatalities = list(
      key = "e167c357-daaa-42bd-aa73-e539ee14a2d4", entity = "vw_BS_Isr_Fatalities",
      src = "v1", dataset_id = "c1523f44-2968-4e6a-979a-5bb84a1f4cde",
      report_id = "c8856647-e870-4856-befa-0f9087f8e236", model_id = 1300830L,
      filters = list()
    ),
    pal_injuries = list(
      key = "d65f26ab-1d4c-4c33-a5e0-8a4afe12ce1c", entity = "vw_BS_Pal_Injuries",
      src = "v1", dataset_id = "b9ab430a-525d-4bc8-8397-e0edd45cd453",
      report_id = "46625751-da8a-42a6-a3e8-d4a3f1a4d570", model_id = 1272286L,
      filters = list(ocha_make_in_filter("v1", "Poc_Period", c("yes", "Yes")))
    ),
    isr_injuries = list(
      key = "ebeb5c54-2c96-4a9c-b913-6a7a8ccf8c00", entity = "vw_BS_Isr_Injuries",
      src = "v",  dataset_id = "5bd7183c-420b-4727-b350-298104f4d4e7",
      report_id = "71f0e246-4767-41d7-882a-9c228a537cdc", model_id = 1272285L,
      filters = list()
    )
  )

  m   <- meta[[type]]
  src <- m$src

  effective_key <- m$key

  for (attempt in seq_len(2L)) {
    # WHERE: dataset-required conditions + NOT NULL guard on the queried column
    where_clause <- c(m$filters, list(ocha_make_not_null_filter(src, col)))

    payload <- list(
      version = "1.0.0",
      queries = list(list(
        Query = list(
          Commands = list(list(
            SemanticQueryDataShapeCommand = list(
              Query = list(
                Version = 2L,
                From    = list(list(Name = src, Entity = m$entity, Type = 0L)),
                Select  = list(list(
                  Column = list(
                    Expression = list(SourceRef = list(Source = src)),
                    Property   = col
                  ),
                  Name = paste0(m$entity, ".", col)
                )),
                Where = where_clause
              ),
              Binding = list(
                Primary       = list(Groupings = list(list(Projections = list(0L)))),
                DataReduction = list(
                  DataVolume = 3L,
                  Primary    = list(Top = list(Count = 1000L))
                ),
                Version = 1L
              ),
              ExecutionMetricsKind = 1L
            )
          ))
        ),
        QueryId            = "",
        ApplicationContext = list(
          DatasetId = m$dataset_id,
          Sources   = list(list(ReportId = m$report_id))
        )
      )),
      cancelQueries = list(),
      modelId       = m$model_id
    )

    result <- tryCatch(
      ocha_fetch_powerbi(effective_key, payload),
      ocha_401_error = function(e) {
        if (attempt == 1L) {
          cli::cli_alert_warning("Resource key stale, attempting auto-refresh...")
          fresh <- tryCatch(un_ocha_get_resource_keys(), error = function(ke) NULL)
          if (!is.null(fresh) && !is.na(fresh[[type]])) {
            effective_key <<- fresh[[type]]
            return(NULL)  # NULL = retry
          }
        }
        stop(conditionMessage(e))  # re-raise after second failure
      }
    )

    if (!is.null(result)) return(result)
  }
}

# ==============================================================================

#' Fetch the Power BI conceptual schema for an OCHA dataset
#'
#' Retrieves column (property) names from the Power BI data model that backs
#' the OCHA casualties dashboards.  Use the returned names with the
#' \code{filters} parameter of \code{\link{un_ocha_fatalities}} to build
#' arbitrary column filters.
#'
#' @param type Character. Which dataset to query. One of
#'   \code{"pal_fatalities"}, \code{"isr_fatalities"},
#'   \code{"pal_injuries"}, \code{"isr_injuries"}.
#' @param table Character. Optional table/entity name to filter to
#'   (e.g. \code{"vw_BS_Pal_Fatalities"}).  If \code{NULL} (default) a named
#'   list is returned with one character vector of column names per table in
#'   the model.
#'
#' @return A character vector when \code{table} is specified, or a named list
#'   of character vectors (one per table) when \code{table = NULL}.  Returns
#'   \code{NULL} invisibly on failure.
#'
#' @examples
#' \dontrun{
#' # All column names for the Palestinian fatalities entity
#' un_ocha_get_schema("pal_fatalities", table = "vw_BS_Pal_Fatalities")
#'
#' # All tables in the model
#' names(un_ocha_get_schema("pal_fatalities"))
#' }
#'
#' @export
#' @importFrom httr GET add_headers status_code content stop_for_status
#' @importFrom jsonlite fromJSON
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning
un_ocha_get_schema <- function(
    type  = c("pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries"),
    table = NULL
) {
  type <- match.arg(type)

  # Only the resource key is needed — the schema endpoint embeds the key in
  # the URL path and also requires it as a header.
  keys <- c(
    pal_fatalities = "60eca1ef-5852-4807-9bc3-4fdb8915c71c",
    isr_fatalities = "e167c357-daaa-42bd-aa73-e539ee14a2d4",
    pal_injuries   = "d65f26ab-1d4c-4c33-a5e0-8a4afe12ce1c",
    isr_injuries   = "ebeb5c54-2c96-4a9c-b913-6a7a8ccf8c00"
  )

  base_url      <- "https://wabi-north-europe-j-primary-api.analysis.windows.net/public/reports"
  effective_key <- keys[[type]]

  for (attempt in seq_len(2L)) {
    cli::cli_alert_info("Fetching conceptual schema for {type}...")

    resp <- httr::GET(
      paste0(base_url, "/", effective_key, "/conceptualschema"),
      httr::add_headers(
        "X-PowerBI-ResourceKey" = effective_key,
        "Accept"                = "application/json"
      )
    )

    if (httr::status_code(resp) == 401L) {
      if (attempt == 1L) {
        cli::cli_alert_warning("Resource key expired \u2014 attempting auto-refresh...")
        fresh <- tryCatch(un_ocha_get_resource_keys(), error = function(e) NULL)
        if (!is.null(fresh) && !is.na(fresh[[type]])) {
          effective_key <- fresh[[type]]
          next
        }
      }
      stop("HTTP 401 \u2013 resource key expired or revoked")
    }
    httr::stop_for_status(resp)

    schema <- jsonlite::fromJSON(
      httr::content(resp, "text", encoding = "UTF-8"),
      simplifyVector = FALSE
    )
    cli::cli_alert_success("Schema retrieved.")

    # Power BI returns either $tables (modern format) or $entity (older format).
    # Columns live in $columns / $properties respectively.
    if (!is.null(schema$tables)) {
      tbl_list  <- schema$tables
      tbl_key   <- "name"
      col_list  <- "columns"
      col_key   <- "name"
    } else if (!is.null(schema$entity)) {
      tbl_list  <- schema$entity
      tbl_key   <- "name"
      col_list  <- "properties"
      col_key   <- "name"
    } else {
      cli::cli_alert_warning(
        "Unrecognised schema structure \u2014 returning the raw parsed list."
      )
      return(schema)
    }

    all_cols <- lapply(tbl_list, function(tbl) {
      cols <- tbl[[col_list]]
      if (is.null(cols) || length(cols) == 0L) return(character(0L))
      vapply(cols, function(col) {
        v <- col[[col_key]]
        if (is.null(v)) "" else as.character(v)
      }, character(1L))
    })
    names(all_cols) <- vapply(tbl_list, function(tbl) {
      v <- tbl[[tbl_key]]
      if (is.null(v)) "" else as.character(v)
    }, character(1L))

    if (!is.null(table)) {
      # Exact match first; fall back to case-insensitive partial match
      idx <- match(table, names(all_cols))
      if (is.na(idx)) {
        hits <- grep(table, names(all_cols), ignore.case = TRUE)
        if (length(hits) == 0L)
          stop("Table '", table, "' not found. Available: ",
               paste(names(all_cols), collapse = ", "))
        idx <- hits[[1L]]
      }
      return(all_cols[[idx]])
    }

    return(all_cols)
  }
}

#' Scrape the current resource keys from the OCHA casualties page
#'
#' The \code{X-PowerBI-ResourceKey} values embedded in OCHA's Power BI dashboards
#' can be revoked or rotated at any time by OCHA.  This function fetches the
#' current keys directly from the page HTML so you do not need to open browser
#' DevTools manually.  \code{\link{un_ocha_fatalities}} calls this function
#' automatically whenever it receives an HTTP 401 response.
#'
#' @details
#' Each Power BI public-report \code{<iframe>} embed URL contains an
#' \code{r=} query parameter whose value is base64-encoded JSON of the form
#' \code{\{"k":"<uuid>","t":"<tenant>"\}}.  The \code{k} field is the resource
#' key.  This function extracts all such base64 blobs from the raw page HTML,
#' decodes them, and returns the four UUIDs in tab order.
#'
#' If OCHA switches to JavaScript-only iframe loading the extraction will return
#' \code{NULL} with a warning, and you will need to update the keys manually
#' from DevTools.
#'
#' @return A named character vector of length 4
#'   (\code{"pal_fatalities"}, \code{"isr_fatalities"},
#'   \code{"pal_injuries"}, \code{"isr_injuries"}),
#'   or \code{NULL} invisibly if extraction fails.
#'
#' @examples
#' \dontrun{
#' keys <- un_ocha_get_resource_keys()
#' print(keys)
#' }
#'
#' @export
#' @importFrom httr GET add_headers status_code content
#' @importFrom jsonlite base64_dec
#' @importFrom cli cli_alert_info cli_alert_success cli_alert_warning
un_ocha_get_resource_keys <- function() {
  page_url <- "https://www.ochaopt.org/data/casualties"
  cli::cli_alert_info("Scraping resource keys from {page_url}...")

  resp <- httr::GET(
    page_url,
    httr::add_headers(
      "User-Agent"      = paste0(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ",
        "AppleWebKit/537.36 (KHTML, like Gecko) ",
        "Chrome/124.0.0.0 Safari/537.36"
      ),
      "Accept"          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language" = "en-US,en;q=0.9"
    )
  )

  if (httr::status_code(resp) != 200L) {
    warning("Could not fetch OCHA page (HTTP ", httr::status_code(resp), ")")
    return(invisible(NULL))
  }

  html <- httr::content(resp, "text", encoding = "UTF-8")

  # Power BI embed r= parameters are base64-encoded JSON that always begin with
  # "eyJ" (base64 for '{"').  Extract every such sequence from the raw HTML.
  r_matches <- unlist(regmatches(
    html,
    gregexpr("eyJ[A-Za-z0-9+/]+=*", html, perl = TRUE)
  ))

  if (length(r_matches) == 0L) {
    warning(
      "No Power BI embed parameters found in the OCHA page HTML. ",
      "The iframes may be loaded by JavaScript. ",
      "Update the resource keys manually from browser DevTools."
    )
    return(invisible(NULL))
  }

  # Decode each base64 blob and pull out the UUID in the k field
  uuid_re <- "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
  k_re    <- paste0('"k":"(', uuid_re, ')"')

  keys <- character(0L)
  for (r_val in unique(r_matches)) {
    padded  <- paste0(r_val, strrep("=", (4L - nchar(r_val) %% 4L) %% 4L))
    decoded <- tryCatch(
      rawToChar(jsonlite::base64_dec(padded)),
      error = function(e) ""
    )
    if (!nzchar(decoded)) next

    k_hit <- regmatches(decoded, regexpr(k_re, decoded, perl = TRUE))
    if (length(k_hit) == 0L || !nzchar(k_hit)) next

    key <- regmatches(k_hit, regexpr(uuid_re, k_hit, perl = TRUE))
    if (length(key) > 0L && nzchar(key)) keys <- c(keys, key)
  }

  keys <- unique(keys)

  if (length(keys) == 0L) {
    warning(
      "Decoded ", length(r_matches), " base64 blob(s) but found no UUID resource keys. ",
      "Page structure may have changed."
    )
    return(invisible(NULL))
  }

  if (length(keys) < 4L) {
    warning("Expected 4 resource keys, found ", length(keys), ".")
  }

  dataset_names <- c("pal_fatalities", "isr_fatalities", "pal_injuries", "isr_injuries")
  out <- stats::setNames(
    c(keys, rep(NA_character_, max(0L, 4L - length(keys))))[seq_len(4L)],
    dataset_names
  )

  cli::cli_alert_success("Extracted {sum(!is.na(out))} / 4 resource keys.")
  out
}
