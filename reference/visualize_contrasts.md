# Visualize Color Contrasts

Shows a visual comparison of a background color with its contrasting
options.

## Usage

``` r
visualize_contrasts(background_color, contrast_level = "AA", max_options = 8)
```

## Arguments

- background_color:

  Character. Hex color code.

- contrast_level:

  Character. Contrast level to show.

- max_options:

  Numeric. Maximum number of contrast options to display.

## Examples

``` r
# Visualize contrasts for apo color
visualize_contrasts("#C1D9D9")

#> Warning: supplied color is neither numeric nor character
#> Error in text.default(n_options/2 + 0.5, 1.75, "Background Color", col = contrast_data$contrasts[1],     font = 2, cex = 1.2): invalid color specification

# Show only high contrast options
visualize_contrasts("#C1D9D9", contrast_level = "high")
#> Warning: supplied color is neither numeric nor character
#> Error in text.default(n_options/2 + 0.5, 1.75, "Background Color", col = contrast_data$contrasts[1],     font = 2, cex = 1.2): invalid color specification
```
