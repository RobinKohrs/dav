# Get Nice Fill Scale for ggplot2

Returns a ggplot2 fill scale using nice color palettes.

## Usage

``` r
scale_nice_fill(palette = "modern", discrete = TRUE, reverse = FALSE, ...)
```

## Arguments

- palette:

  Character. Name of the palette to use.

- discrete:

  Logical. If TRUE, returns scale_fill_manual for discrete data. If
  FALSE, returns scale_fill_gradientn for continuous data.

- reverse:

  Logical. If TRUE, reverses the color order.

- ...:

  Additional arguments passed to the ggplot2 scale function.

## Value

A ggplot2 scale function.

## Examples

``` r
library(ggplot2)

# For discrete data
ggplot(iris, aes(x = Species, fill = Species)) +
  geom_bar() +
  scale_nice_fill("nature")
#> Warning: No shared levels found between `names(values)` of the manual scale and the
#> data's fill values.
#> Warning: No shared levels found between `names(values)` of the manual scale and the
#> data's fill values.

```
