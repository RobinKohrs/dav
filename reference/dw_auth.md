# Authenticate with Datawrapper for a Specific Employer

These functions manage and set the `DW_KEY` environment variable for the
current R session, allowing you to easily switch between different
Datawrapper accounts (e.g., for different employers).

## Usage

``` r
dw_dst(api_key = NULL)

dw_ndr(api_key = NULL)
```

## Arguments

- api_key:

  Optional. A character string containing the Datawrapper API key. If
  provided, the key will be saved to your `.Renviron` file for future
  use.

## Value

Invisibly returns the API key that was set. It also prints a
confirmation message to the console.

## Details

The first time you use one of these functions for a specific employer,
you must provide the `api_key`. This key will be stored securely in your
local `.Renviron` file as `DW_KEY_DST` or `DW_KEY_NDR`. On subsequent
uses, you can call the function without an `api_key` to load the stored
key for your current R session.

## Author

Benedict Witzenberger, Robin Kohrs

## Examples

``` r
if (FALSE) { # \dontrun{
# First time usage (stores the key):
dw_dst(api_key = "your_api_key_for_dst")

# Subsequent usage in a new R session:
dw_dst()
} # }
if (FALSE) { # \dontrun{
# First time usage (stores the key):
dw_ndr(api_key = "your_api_key_for_ndr")

# Subsequent usage in a new R session:
dw_ndr()
} # }
```
