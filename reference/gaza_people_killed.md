# Download and Read "Killed in Gaza" Data from HDX

This function downloads the "Killed in Gaza" dataset from the
Humanitarian Data Exchange (HDX) page for "The State of Palestine -
Escalation of Hostilities". It then reads the downloaded Excel file and
returns its content as a tibble.

## Usage

``` r
gaza_people_killed(sheet = 1)
```

## Arguments

- sheet:

  The sheet to read from the Excel file. Can be a string (sheet name) or
  an integer (sheet number). Defaults to `1` (the first sheet).

- ...:

  Additional arguments to pass to
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html).

## Value

A tibble containing the data from the "Killed in Gaza" Excel file.

## Details

Data on people killed in the gaza strip

The function specifies the HDX page URL for the "Killed in Gaza" data,
calls an internal helper (`humdata_download_file`) to download the file
to a temporary location, reads the data from the first sheet of the
Excel file using
[`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html),
and then deletes the temporary file. Column names are cleaned using
[`janitor::clean_names()`](https://sfirke.github.io/janitor/reference/clean_names.html).

## Examples

``` r
if (FALSE) { # \dontrun{
  try({
    # Ensure you have an internet connection for this example to run.
    killed_data = gaza_people_killed()
    print(head(killed_data))
  }, error = function(e) {
    message("An error occurred during the example: ", e$message)
  })
} # }
```
