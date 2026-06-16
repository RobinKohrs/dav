# Use STMatilda Fonts in ggplot2

This function returns a ggplot2 theme component that sets the font
family to "STMatilda" (Text or Info variants). It is designed to be
added to any ggplot object or theme.

## Usage

``` r
dav_use_matilda(type = c("text", "info"), base_size = NULL)
```

## Arguments

- type:

  Character string, either "text" or "info". Determines which font
  family to use. Defaults to "text".

  - "text": Uses "STMatilda Text Variable Roman"

  - "info": Uses "STMatilda Info Variable Roman"

- base_size:

  Optional numeric. If provided, sets the base font size for the plot
  text.

## Value

A [`ggplot2::theme`](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## Examples

``` r
if (FALSE) { # \dontrun{
library(ggplot2)

# Use with default theme
ggplot(mtcars, aes(mpg, wt)) +
  geom_point() +
  labs(title = "Matilda Text Font") +
  dav_use_matilda("text")

# Use with theme_kjn or others
ggplot(mtcars, aes(mpg, wt)) +
  geom_point() +
  labs(title = "Matilda Info Font") +
  theme_minimal() +
  dav_use_matilda("info", base_size = 14)
} # }
```
