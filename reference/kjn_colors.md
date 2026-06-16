# KJN Color Palette

Returns a named vector of colors used in KJN visualizations.

## Usage

``` r
kjn_colors(names = NULL, as_hex = TRUE)
```

## Arguments

- names:

  Character vector of color names to return. If NULL (default), returns
  all colors. Available colors: "nachtblau", "himmelblau", "eisblau",
  "feuerrot", "orange".

- as_hex:

  Logical. If TRUE (default), returns hex color codes. If FALSE, returns
  the named vector.

## Value

A named character vector of hex color codes.

## Examples

``` r
# Get all colors
kjn_colors()
#>  nachtblau himmelblau    eisblau   feuerrot     orange 
#>  "#072e6b"  "#9cc9e0"  "#e1edf7"  "#a40f15"  "#fa6847" 

# Get specific colors
kjn_colors(c("nachtblau", "orange"))
#> nachtblau    orange 
#> "#072e6b" "#fa6847" 

# Use in ggplot
library(ggplot2)
ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point(color = kjn_colors("feuerrot"))

```
