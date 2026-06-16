# Create a Self-Contained HTML Image Swiper

This function generates the HTML, CSS, and JavaScript for a responsive
image slider. It allows for a dynamic number of images, navigation
controls, and an optional fixed overlay.

## Usage

``` r
html_create_image_swiper(
  image_data,
  overlay_path = NULL,
  gradient_color = "hsla(180, 23%, 81%, 1)",
  gradient_stops = NULL,
  aspect_ratio = "1/1",
  max_width = NULL,
  debounce_delay = 0,
  animation_duration = 0.3,
  object_fit = "contain",
  main_image_width = 60,
  output_file = NULL,
  overwrite = TRUE,
  dot_size = "0.625rem",
  caption_fade_duration = 0.5,
  include_html_header = FALSE,
  title = NULL,
  subtitle = NULL,
  caption_position = c("inside", "outside"),
  outside_caption_position = c("bottom", "top"),
  dots_position = c("bottom", "top"),
  full_screen_mobile = FALSE
)
```

## Arguments

- image_data:

  A list of lists. Each inner list must contain a `path` (a string for
  the image source URL) and can optionally contain a `caption` (a string
  to be displayed over the image).

- overlay_path:

  An optional string specifying the path to an overlay image.

- gradient_color:

  An optional string specifying the color for the edge gradient.
  Defaults to "hsla(180, 23%, 81%, 1)" (light blue-green). Set to NULL
  to disable the gradient.

- gradient_stops:

  An optional named character vector where names are percentage stops
  (e.g., `'0'`, `'50'`) and values are CSS colors (e.g., `'#ffffff'`,
  `'transparent'`). This allows for creating complex, multi-color
  gradients. If `NULL` (the default), a standard gradient is created
  using `gradient_color`.

- aspect_ratio:

  A string defining the aspect ratio for the slider items, e.g., "1/1"
  for a square or "16/9" for widescreen. Defaults to "1/1".

- max_width:

  An optional numeric value for the maximum width of the container in
  pixels. Defaults to `NULL`, allowing the slider to fill its parent's
  width.

- debounce_delay:

  An optional integer. The debounce delay in milliseconds for the scroll
  event. Defaults to 0 (no delay). Set to a positive value (e.g., 50) to
  delay the dot indicator update until scrolling has paused.

- animation_duration:

  An optional numeric value. The duration of the dot indicator's
  grow/shrink animation in seconds. Defaults to 0.3.

- object_fit:

  A string specifying how an image should be resized to fit its
  container. Common values are "cover", "contain", "fill", "none", or
  "scale-down". Defaults to "contain".

- main_image_width:

  An optional numeric value (1-100) for the percentage width of the
  central image. Defaults to 60.

- output_file:

  An optional string. If provided, the generated HTML will be saved to
  this file path. Defaults to `NULL`.

- overwrite:

  A logical value. If `TRUE` (the default), an existing output file will
  be overwritten. If `FALSE`, the function will stop with an error if
  the file already exists.

- dot_size:

  A string specifying the CSS size for the navigation dots (e.g.,
  "1rem", "10px", "4pt"). Defaults to "0.625rem".

- include_html_header:

  A logical value. If `TRUE`, the output file will be a complete HTML
  document, including the necessary viewport meta tag for proper mobile
  scaling. Defaults to `FALSE`, which outputs only the HTML fragment.

- title:

  An optional string. A header title to display above the slider.

- subtitle:

  An optional string. A subtitle to display below the title.

- caption_position:

  A string, either "inside" (default) or "outside". If "inside",
  captions are overlayed on the image. If "outside", they are placed
  above or below the image as standard text.

- outside_caption_position:

  A string, either "bottom" (default) or "top". Only applies if
  `caption_position` is "outside".

- dots_position:

  A string, either "bottom" (default) or "top". Controls where the
  navigation dots are placed relative to the slider.

- full_screen_mobile:

  A logical value. If `TRUE`, the swiper will expand to full width
  (margin -20px, width calc(100% + 40px)) on screens below 615px.
  Defaults to `FALSE`.

## Value

An
[`htmltools::tagList`](https://rstudio.github.io/htmltools/reference/tagList.html)
object that can be rendered directly in R Markdown, Shiny, or other
HTML-supporting R environments.

## Examples

``` r
# Define a list of images and their captions
image_list <- list(
  list(path = "http://b.staticfiles.at/elm/static/2025-dateien/first.webp", caption = "15. Oktober 2023"),
  list(path = "http://b.staticfiles.at/elm/static/2025-dateien/middle.webp"),
  list(path = "http://b.staticfiles.at/elm/static/2025-dateien/last.webp", caption = "11. Mai 2025")
)

# Create the swiper (will be an HTML object)
swiper_widget <- html_create_image_swiper(
  image_data = image_list,
  overlay_path = "http://b.staticfiles.at/elm/static/2025-dateien/slider_overview_final.png",
  gradient_color = "hsla(180, 23%, 81%, 1)",
  max_width = 615, # Optional: Set a max-width for the container
  caption_position = "outside",
  dots_position = "top"
)
```
