# KJN Theme for ggplot2 with Markdown Support

This theme provides a clean look for ggplot2 plots, using Roboto and
black text, and leverages
[`ggtext::element_markdown()`](https://wilkelab.org/ggtext/reference/element_markdown.html)
for enhanced text styling capabilities in titles, subtitles, captions,
axis titles, and legend text. It builds upon
[`theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html).

## Usage

``` r
theme_kjn(
  base_size_px = NULL,
  base_family = "Roboto",
  target_device = "desktop"
)
```

## Arguments

- base_size_px:

  Base font size in pixels (default 14px for desktop, 12px for mobile).
  This will be directly used where `element_markdown` supports pixel
  sizes. For elements still using `element_text` or where
  [`rel()`](https://ggplot2.tidyverse.org/reference/element.html) is
  used with `element_markdown`, this acts more like a reference point.

- base_family:

  Base font family. Defaults to "Roboto".

- target_device:

  A character string: "desktop" (default) or "mobile". Influences
  default `base_size_px` and relative text size multipliers.

## Value

A [`ggplot2::theme`](https://ggplot2.tidyverse.org/reference/theme.html)
object.

## Details

This theme attempts to use the "Roboto" font family. For this to work
correctly, **"Roboto" should be installed as a system font**. If not
found, a message is displayed, and `ggplot2` may fall back to a default.
Users can also employ the `showtext` package for font management.

**Using Markdown:** When using this theme, you can use markdown/HTML in
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) for
elements like `title`, `subtitle`, `caption`, `x`, `y`, and
`legend.title`. Example:
`labs(title = "My <b style='color:blue;'>Awesome</b> Title <small>(in 10px)</small>")`
Note: `element_markdown` primarily affects theme elements. For markdown
in `labs`,
[`ggtext::geom_textbox`](https://wilkelab.org/ggtext/reference/geom_textbox.html)
or
[`ggtext::geom_richtext`](https://wilkelab.org/ggtext/reference/geom_richtext.html)
might be needed for complex geoms, but for
[`labs()`](https://ggplot2.tidyverse.org/reference/labs.html) elements,
`theme_markdown` is often sufficient.

## Examples

``` r
library(ggplot2)
library(ggtext) # For markdown elements

# --- Optional: Showtext for Roboto if not system-installed ---
#
if (FALSE) { # \dontrun{
#   library(showtext)
#   font_add_google("Roboto", "Roboto")
#   showtext_auto()
#
} # }

data(mpg, package = "ggplot2")
p_base <- ggplot(mpg, aes(x = displ, y = hwy)) +
  geom_point(aes(color = factor(cyl)), alpha = 0.7)

# --- Desktop Example with Markdown ---
p_desk_md <- p_base +
  theme_kjn_markdown(target_device = "desktop") +
  labs(
    title = "Fuel Efficiency <b style='font-size:22px; color:#0072B2;'>Analysis</b>",
    subtitle = "Investigating the relationship between *engine displacement* and <i>highway MPG</i>.<br>Data from 1999 and 2008.",
    x = "Engine Displacement (<span style='font-style:italic;'>Liters</span>)",
    y = "Highway <span style='font-weight:bold;'>MPG</span>",
    caption = "Source: <span style='color:gray;'>ggplot2 mpg dataset</span> | Chart: KJN",
    color = "<b style='font-size:11px'>Cylinders:</b>"
  )
#> Error in theme_kjn_markdown(target_device = "desktop"): could not find function "theme_kjn_markdown"
print(p_desk_md)
#> Error: object 'p_desk_md' not found

# --- Mobile Example with Markdown ---
p_mob_md <- p_base +
  theme_kjn_markdown(target_device = "mobile") +
  labs(
    title = "Fuel Efficiency <b style='font-size:18px; color:#D55E00;'>Analysis</b>",
    subtitle = "Engine displacement vs. <i>highway MPG</i>.<br>Data: 1999 & 2008.",
    x = "Displacement (<span style='font-style:italic;'>L</span>)",
    y = "<span style='font-weight:bold;'>MPG</span> (Highway)",
    caption = "Source: <span style='color:gray;'>mpg data</span> | KJN",
    color = "<b style='font-size:10px'>Cyl.:</b>"
  )
#> Error in theme_kjn_markdown(target_device = "mobile"): could not find function "theme_kjn_markdown"
print(p_mob_md)
#> Error: object 'p_mob_md' not found
```
