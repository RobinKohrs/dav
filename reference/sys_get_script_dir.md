# Get Directory of the Currently Executing R Script

This function attempts to robustly determine and return the absolute
path to the directory containing the currently executing R script. It
tries various methods to accommodate different execution contexts such
as RStudio, `knitr` (R Markdown/Quarto),
[`source()`](https://rdrr.io/r/base/source.html), and `Rscript`. It
prints an informative message indicating the method used.

## Usage

``` r
sys_get_script_dir(script_path_override = NULL, verbose = TRUE)
```

## Arguments

- script_path_override:

  (Optional) A character string. If provided, this path will be used
  directly instead of attempting auto-detection. If it's a file path,
  its directory will be returned. If it's a directory path, it will be
  returned as is. This is useful for testing or when the script's
  location is known through other means.

- verbose:

  Logical. If `TRUE` (default), prints a message indicating how the
  script directory was determined or if it failed.

## Value

A character string representing the absolute path to the directory of
the currently executing script.

## Details

The function employs the following strategies in order to find the
script's path:

1.  **RStudio API:** If run within RStudio and a document is active, it
    uses `rstudioapi::getActiveDocumentContext()$path`.

2.  **`knitr` Environment:** If the script is processed by `knitr`
    (e.g., within an R Markdown or Quarto document), it uses
    `knitr::current_input(dir = FALSE)` to get the source file, then its
    directory.

3.  **[`source()`](https://rdrr.io/r/base/source.html) Context:** If the
    script is being [`source()`](https://rdrr.io/r/base/source.html)d,
    it checks parent frames for an `ofile` component.

4.  **`Rscript` Execution:** If the script is run via `Rscript` from the
    command line, it parses
    [`commandArgs()`](https://rdrr.io/r/base/commandArgs.html) for the
    `--file=` argument.

If all methods fail to determine the script's path, the function will
stop with an error message. It does *not* fall back to the working
directory ([`getwd()`](https://rdrr.io/r/base/getwd.html)) to avoid
ambiguity.

The returned path is normalized to an absolute path.

## Examples

``` r
if (FALSE) { # \dontrun{
# --- Assuming this code is saved in a file named "my_script.R" ---

# 1. When run directly in RStudio (after saving the script):
#    script_dir <- sys_get_script_dir()
#    # Expected output:
#    # ✓ Script directory determined via User Override (File Path): /path/to/temp_dir_for_file
#    # or for auto-detection:
#    # ℹ Script directory determined via RStudio API: /path/to/your/script
#    print(script_dir)

# 5. Using the override (e.g., for testing or known path):
temp_file <- tempfile(fileext = ".R")
writeLines("print('hello')", temp_file)
known_dir <- sys_get_script_dir(script_path_override = temp_file) # verbose=TRUE by default
unlink(temp_file)

temp_dir <- tempfile("my_dir_")
dir.create(temp_dir)
known_dir_from_dir <- sys_get_script_dir(script_path_override = temp_dir)
unlink(temp_dir, recursive = TRUE)

# Example of failure:
tryCatch({
  # In a context where it can't be found (e.g. bare R console with no script)
  sys_get_script_dir(verbose = TRUE)
}, error = function(e) { message(e$message) })
} # }
```
