# Show Nice Color Palettes

Displays color palettes visually using base R plotting.

## Usage

``` r
show_nice_colors(palette = NULL, show_contrasts = TRUE)
```

## Arguments

- palette:

  Character. Name of the palette to display. If NULL (default), displays
  all palettes.

- show_contrasts:

  Logical. If TRUE (default), shows contrasting colors.

## Examples

``` r
# Show all palettes
show_nice_colors()


# Show specific palette
show_nice_colors("modern")


# Show without contrasts
show_nice_colors("vibrant", show_contrasts = FALSE)

```
