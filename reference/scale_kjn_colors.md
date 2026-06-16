# Get KJN Color Scale for ggplot2

Returns a ggplot2 color scale using KJN colors.

## Usage

``` r
scale_kjn_colors(discrete = TRUE, reverse = FALSE, ...)
```

## Arguments

- discrete:

  Logical. If TRUE, returns scale_color_manual for discrete data. If
  FALSE, returns scale_color_gradientn for continuous data.

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
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
  geom_point() +
  scale_kjn_colors()
#> Warning: No shared levels found between `names(values)` of the manual scale and the
#> data's colour values.
#> Warning: No shared levels found between `names(values)` of the manual scale and the
#> data's colour values.


# For continuous data
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Petal.Length)) +
  geom_point() +
  scale_kjn_colors(discrete = FALSE)

```
