# Create an HTML Info Card

Generates HTML for a responsive info card, suitable for displaying key
metrics or pieces of information. It supports custom styling,
ressort-based color palettes, optional animations for numeric values,
and accessibility considerations for screen readers.

## Usage

``` r
html_create_info_card(
  main_value,
  main_text,
  headline = NULL,
  source_text = NULL,
  source_link = NULL,
  sr_only_main_value_label = NULL,
  show_percentage_sign = FALSE,
  animation_duration_ms = 1500,
  animation_trigger_threshold = 5,
  animate_value = FALSE,
  animation_initial_display = "0",
  show_percentage_bar = FALSE,
  animate_percentage_bar = TRUE,
  percentage_bar_color = "rgba(0, 0, 0, 0.1)",
  ressort_name = NULL,
  background_color = "#f0f0f0",
  text_color = "#333333",
  border_color = "#cccccc",
  border_gradient = NULL,
  card_width = "100%",
  border_width = 2,
  font_family = "STMatilda Text Variable, system-ui, serif",
  headline_css = "font-size: 1.1em; font-weight: bold;",
  main_text_css = "font-size: 1.1em;",
  main_value_css = "font-size: 1.7em; font-weight: bold;",
  source_css = "font-size: 0.8em;",
  shadow_intensity = "middle",
  number_format = NULL
)
```

## Arguments

- main_value:

  Numeric or character. The primary value to display prominently. If
  numeric (e.g., 10000.55), it will be formatted according to
  `number_format`. If character (e.g., "Active"), it will be displayed
  as-is. If `animate_value` is TRUE and `main_value` is numeric, the
  value will be animated.

- main_text:

  Character string. A short descriptive text displayed below the
  `main_value` (e.g., "Users Online", "Completion Rate").

- headline:

  Optional. Character string. A headline displayed at the top of the
  card.

- source_text:

  Optional. Character string. Text for a source attribution line (e.g.,
  "Source: Annual Report").

- source_link:

  Optional. Character string. A URL to link the `source_text` to.
  `source_text` must be provided.

- sr_only_main_value_label:

  Optional. Character string. A label to append to `main_value`
  specifically for screen readers. This helps form a more complete and
  natural sentence. For example, if `main_value` is "10,000" and
  `sr_only_main_value_label` is "active users", the screen reader would
  announce "10,000 active users". If NULL, the function attempts to use
  `main_text` as a fallback label, or just `main_value` if `main_text`
  is also empty. Providing a specific label here is recommended for best
  accessibility.

- show_percentage_sign:

  Optional. Logical. If TRUE, adds a percentage sign (%) to the main
  value. Defaults to FALSE. Use this to explicitly control when to show
  the percentage sign.

- animation_duration_ms:

  Numeric. Duration of all animations in milliseconds. This controls
  both the number animation (if `animate_value` is TRUE) and the
  percentage bar animation (if `show_percentage_bar` and
  `animate_percentage_bar` are TRUE). Defaults to 1500.

- animation_trigger_threshold:

  Numeric. Percentage of the viewport height (0-100) that should be
  visible above the bottom before triggering the animation. For example,
  5 means the animation starts when the element is 5% above the bottom
  of the viewport. Defaults to 5.

- animate_value:

  Logical. If TRUE and `main_value` is numeric, animates the value from
  `animation_initial_display` to its final state. Defaults to FALSE.

- animation_initial_display:

  Character string. Initial text for `main_value` before animation. Only
  used if `animate_value` is TRUE. Defaults to "0".

- show_percentage_bar:

  Logical. If TRUE and `main_value` is a number between 0 and 100,
  displays a background bar that fills from left to right. Must be TRUE
  for any bar animation to occur.

- animate_percentage_bar:

  Logical. If TRUE and `show_percentage_bar` is TRUE, animates the
  percentage bar from 0 to the final value using
  `animation_duration_ms`. Defaults to TRUE.

- percentage_bar_color:

  Character string. CSS color for the percentage bar. Only used if
  `show_percentage_bar` is TRUE. Defaults to "rgba(0, 0, 0, 0.1)".

- ressort_name:

  Optional. Character string. The name of a "ressort" (e.g., department,
  section like 'dst_wirtschaft', 'dst_apo'). If provided and recognized
  from an internal list, applies a predefined color palette (background,
  text, border). Overrides default colors unless specific color
  arguments are also provided.

- background_color:

  Optional. Character string. CSS color for the card's background (e.g.,
  "#f0f0f0", "white"). Defaults to light gray. Overridden by
  `ressort_name` if not explicitly set.

- text_color:

  Optional. Character string. CSS color for the card's text (e.g.,
  "#333333", "black"). Defaults to dark gray. Overridden by
  `ressort_name` if not explicitly set.

- border_color:

  Optional. Character string. CSS color for the card's border (e.g.,
  "#cccccc", "blue"). Defaults to medium gray. Overridden by
  `ressort_name` (uses accent color) if not explicitly set.

- border_gradient:

  Optional. Character string. CSS gradient for the card's border. Only
  used if not NULL and not empty.

- card_width:

  Optional. Character string. CSS width for the card (e.g., "300px",
  "100%", "auto"). Defaults to "min(100%, 350px)" which ensures the card
  is never wider than 350px but can shrink on smaller screens.

- border_width:

  Optional. Numeric. Width of the card's border in pixels. Defaults to
  2.

- font_family:

  Optional. Character string. CSS `font-family` string for the card's
  text. Defaults to "STMatilda Text Variable, system-ui, serif".

- headline_css:

  Optional. Character string. A full inline CSS string (e.g. "font-size:
  1.1em; font-weight: bold;") for the headline.

- main_text_css:

  Optional. Character string. A full inline CSS string (e.g. "font-size:
  1.1em;") for the main text.

- main_value_css:

  Optional. Character string. A full inline CSS string (e.g. "font-size:
  1.7em; font-weight: bold;") for the main value.

- source_css:

  Optional. Character string. A full inline CSS string (e.g. "font-size:
  0.8em;") for the source text.

- shadow_intensity:

  Optional. Character string. Controls the box shadow intensity. Valid
  values: "none", "low", "middle" (or "medium"), "intense" (or "high").
  Defaults to "middle".

- number_format:

  Optional. Character string. The locale to use for number formatting
  (e.g., "de-DE" for German format). If NULL, no specific formatting is
  applied. Common values: "de-DE" (German), "en-US" (US), "fr-FR"
  (French). Only applies when `animate_value` is TRUE.

- \#:

  — Formatting Parameters —
