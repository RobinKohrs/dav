# Ensure Directory Structure Exists (Custom Heuristic for File/Directory)

Creates the necessary directory structure. It uses a custom heuristic to
determine if the input `path` is intended as a file or a directory.

## Usage

``` r
sys_make_path(path, showWarnings = FALSE, mode = "0777")
```

## Arguments

- path:

  A character string specifying the full path.

- showWarnings:

  Logical. Passed to
  [`dir.create()`](https://rdrr.io/r/base/files2.html). Defaults to
  `FALSE`.

- mode:

  Character. The mode for
  [`dir.create()`](https://rdrr.io/r/base/files2.html). Defaults to
  `"0777"`.

## Value

The original input `path`, returned invisibly.

## Details

The function's heuristic is as follows:

1.  If `path` already exists:

    - If it's a directory (per
      [`file.info()`](https://rdrr.io/r/base/file.info.html)), no
      creation action is taken for it.

    - If it's a file (per
      [`file.info()`](https://rdrr.io/r/base/file.info.html)), its
      parent directory is targeted for creation.

2.  If `path` does not exist:

    - If the original `path` string ends with one or more path
      separators ('/' or '\\), the full `path` is treated as a directory
      to be created.

    - Else, if the last component (basename) of the `path` does *not*
      contain a dot ('.'), the full `path` is treated as a directory to
      be created.

    - Otherwise (does not end with a separator AND basename contains a
      dot), it's treated as a file path, and its parent directory is
      targeted for creation. Provides console feedback using the cli
      package.
