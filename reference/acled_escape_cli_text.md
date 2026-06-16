# Download ACLED events via the myACLED OAuth API

Calls the current ACLED API (`acleddata.com/api/acled/read`) with OAuth
login. Handles pagination (5,000 rows per page) and optional interactive
event-type selection. Vault guide:
`topics/_wiki/methoden/acled-api-journalist.md`.

## Usage

``` r
acled_escape_cli_text(x)
```

## Arguments

- email_address:

  Your myACLED email address. If `NULL` or missing, uses `ACLED_EMAIL`
  env var.

- password:

  Your myACLED password. If `NULL` or missing, uses `ACLED_PASSWORD` env
  var.

- token:

  Optional Bearer token (24 h). Skips login when set. Uses
  `ACLED_ACCESS_TOKEN` env var if `NULL`.

- start_date:

  Character string or Date object. Start date (YYYY-MM-DD). Required.

- end_date:

  Character string or Date object. End date (YYYY-MM-DD). Required.

- country:

  Character vector. Optional. ACLED country name(s). Example:
  `c("Yemen", "Syria")`.

- region:

  Character or numeric vector. Optional. ACLED region name(s) or
  code(s). See ACLED API documentation or
  [`acled.api::get.api.regions()`](https://rdrr.io/pkg/acled.api/man/get.api.regions.html).

- admin1:

  Character vector. Optional. First-level administrative region(s).

- admin2:

  Character vector. Optional. Second-level administrative region(s).

- admin3:

  Character vector. Optional. Third-level administrative region(s).

- event_types:

  Character vector. Optional. ACLED event type(s). If `NULL` and
  `interactive_events = FALSE`, all event types considered. If
  `interactive_events = TRUE`, this argument is ignored initially.
  Example: `c("Battles", "Explosions/Remote violence")`.

- sub_event_types:

  Character vector. Optional. ACLED sub-event type(s). If `NULL`, all
  sub-types for selected `event_types` considered. If
  `interactive_events = TRUE`, this argument is ignored initially.
  Example: `c("Air/drone strike", "Armed clash")`.

- interactive_events:

  Logical. If `TRUE`, prompts user to select event types and sub-event
  types. Defaults to `FALSE`.

- page_limit:

  Numeric. Records per API page request. Max 5000.

- max_pages:

  Numeric. Maximum pages to fetch to prevent overly long requests.

- output_format:

  Character. "df" for a data.frame or "raw_json" for raw list.

- ...:

  Additional query parameters to pass directly to the ACLED API as a
  named list (e.g., `list(terms_of_use="yes", source="Reuters")`). These
  will be added to the manually constructed URL string. See ACLED API
  guide for available parameters.

## Value

A data.frame containing the queried ACLED event data (if
`output_format = "df"`), or a list of parsed JSON content from each page
(if `output_format = "raw_json"`). Returns NULL if a critical error
occurs or no data is found.

## Details

Authentication uses myACLED **email + password** (no separate API key).
Provide via arguments or environment variables `ACLED_EMAIL` and
`ACLED_PASSWORD`.

## Examples

``` r
if (FALSE) { # \dontrun{
# --- Set environment variables first (recommended) ---
# Sys.setenv(ACLED_EMAIL = "you@newsroom.example")
# Sys.setenv(ACLED_PASSWORD = "your-myacled-password")

# Lebanon events (Sep 2024 – May 2026)
lebanon = acled_download_events(
  start_date = "2024-09-01",
  end_date = "2026-05-31",
  country = "Lebanon"
)
if (!is.null(yemen_explosions) && nrow(yemen_explosions) > 0) {
  print(head(yemen_explosions[, c("event_date", "country", "admin1", "event_type")]))
}

# Example 2: Interactive selection (run in an interactive R session)
# interactive_data = acled_download_events(
#   start_date = "2024-01-01",
#   end_date = "2024-01-07",
#   country = "Ukraine",
#   interactive_events = TRUE
# )
# if (!is.null(interactive_data)) print(head(interactive_data))
} # }
```
