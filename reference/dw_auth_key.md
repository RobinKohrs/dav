# Helper Function to Set and Load Datawrapper API Keys

This internal function handles the logic for storing, retrieving, and
setting employer-specific API keys.

## Usage

``` r
dw_auth_key(key_name, api_key = NULL)
```

## Arguments

- key_name:

  The name of the environment variable to use for storage (e.g.,
  "DW_KEY_DST").

- api_key:

  The API key string, or `NULL`.
