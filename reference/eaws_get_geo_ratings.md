# Get EAWS Microregions with Ratings

This function downloads EAWS microregions from GitLab, fetches their
names, and joins them with avalanche ratings for a specific date.

## Usage

``` r
eaws_get_geo_ratings(
  date = Sys.Date(),
  output_dir = "data_raw/microregions",
  gitlab_token = NULL,
  language = "de",
  force_download = FALSE
)
```

## Arguments

- date:

  Date object or character string (YYYY-MM-DD). Defaults to today's
  date.

- output_dir:

  Directory to save downloaded microregions. Defaults to
  "data_raw/microregions".

- gitlab_token:

  Optional GitLab private token.

- language:

  Language for microregion names (e.g., "de", "en"). Default is "de".

- force_download:

  Logical. If TRUE, re-downloads microregions even if they exist.

## Value

An sf object containing microregions with names and ratings.
