# Scrape the current resource keys from the OCHA casualties page

The `X-PowerBI-ResourceKey` values embedded in OCHA's Power BI
dashboards can be revoked or rotated at any time by OCHA. This function
fetches the current keys directly from the page HTML so you do not need
to open browser DevTools manually.
[`un_ocha_fatalities`](https://robinkohrs.github.io/dav/reference/un_ocha_fatalities.md)
calls this function automatically whenever it receives an HTTP 401
response.

## Usage

``` r
un_ocha_get_resource_keys()
```

## Value

A named character vector of length 4 (`"pal_fatalities"`,
`"isr_fatalities"`, `"pal_injuries"`, `"isr_injuries"`), or `NULL`
invisibly if extraction fails.

## Details

Each Power BI public-report `<iframe>` embed URL contains an `r=` query
parameter whose value is base64-encoded JSON of the form
`{"k":"<uuid>","t":"<tenant>"}`. The `k` field is the resource key. This
function extracts all such base64 blobs from the raw page HTML, decodes
them, and returns the four UUIDs in tab order.

If OCHA switches to JavaScript-only iframe loading the extraction will
return `NULL` with a warning, and you will need to update the keys
manually from DevTools.

## Examples

``` r
if (FALSE) { # \dontrun{
keys <- un_ocha_get_resource_keys()
print(keys)
} # }
```
