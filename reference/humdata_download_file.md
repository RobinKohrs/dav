# Download File from HDX Page

Downloads a file from an HDX dataset page using a CSS selector to find
the download link.

## Usage

``` r
humdata_download_file(
  page_url,
  css_selector = "a.resource-download-button",
  base_url = "https://data.humdata.org"
)
```

## Arguments

- page_url:

  The full URL of the HDX dataset page.

- css_selector:

  The CSS selector to identify the download link tag.

- base_url:

  The base URL of the HDX site (e.g., "https://data.humdata.org").

## Value

Path to the downloaded temporary file.
