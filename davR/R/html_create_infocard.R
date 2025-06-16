#' Create an HTML Info Card
#'
#' Generates HTML for a responsive info card, suitable for displaying key metrics or pieces of information.
#' It supports custom styling, ressort-based color palettes, optional animations for numeric values,
#' and accessibility considerations for screen readers.
#'
#' @param # --- Content Parameters ---
#' @param main_value Numeric or character. The primary value to display prominently.
#'   If numeric (e.g., 10000.55), it will be formatted according to `number_format`.
#'   If character (e.g., "Active"), it will be displayed as-is.
#'   If `animate_value` is TRUE and `main_value` is numeric, the value will be animated.
#' @param main_text Character string. A short descriptive text displayed below the `main_value` (e.g., "Users Online", "Completion Rate").
#' @param headline Optional. Character string. A headline displayed at the top of the card.
#' @param source_text Optional. Character string. Text for a source attribution line (e.g., "Source: Annual Report").
#' @param source_link Optional. Character string. A URL to link the `source_text` to. `source_text` must be provided.
#' @param sr_only_main_value_label Optional. Character string. A label to append to `main_value` specifically for screen readers.
#'   This helps form a more complete and natural sentence. For example, if `main_value` is "10,000" and
#'   `sr_only_main_value_label` is "active users", the screen reader would announce "10,000 active users".
#'   If NULL, the function attempts to use `main_text` as a fallback label, or just `main_value` if `main_text` is also empty.
#'   Providing a specific label here is recommended for best accessibility.
#' @param show_percentage_sign Optional. Logical. If TRUE, adds a percentage sign (%) to the main value.
#'   Defaults to FALSE. Use this to explicitly control when to show the percentage sign.
#'
#' @param # --- Animation Parameters ---
#' @param animation_duration_ms Numeric. Duration of all animations in milliseconds.
#'   This controls both the number animation (if `animate_value` is TRUE) and
#'   the percentage bar animation (if `show_percentage_bar` and `animate_percentage_bar` are TRUE).
#'   Defaults to 1500.
#' @param animation_trigger_threshold Numeric. Percentage of the viewport height (0-100)
#'   that should be visible above the bottom before triggering the animation.
#'   For example, 5 means the animation starts when the element is 5% above the bottom of the viewport.
#'   Defaults to 5.
#' @param animate_value Logical. If TRUE and `main_value` is numeric,
#'   animates the value from `animation_initial_display` to its final state.
#'   Defaults to FALSE.
#' @param animation_initial_display Character string. Initial text for `main_value` before animation.
#'   Only used if `animate_value` is TRUE. Defaults to "0".
#'
#' @param # --- Percentage Bar Parameters ---
#' @param show_percentage_bar Logical. If TRUE and `main_value` is a number between 0 and 100,
#'   displays a background bar that fills from left to right. Must be TRUE for any bar animation to occur.
#' @param animate_percentage_bar Logical. If TRUE and `show_percentage_bar` is TRUE,
#'   animates the percentage bar from 0 to the final value using `animation_duration_ms`.
#'   Defaults to TRUE.
#' @param percentage_bar_color Character string. CSS color for the percentage bar.
#'   Only used if `show_percentage_bar` is TRUE. Defaults to "rgba(0, 0, 0, 0.1)".
#'
#' @param # --- Styling Parameters ---
#' @param ressort_name Optional. Character string. The name of a "ressort" (e.g., department, section like 'dst_wirtschaft', 'dst_apo').
#'   If provided and recognized from an internal list, applies a predefined color palette (background, text, border).
#'   Overrides default colors unless specific color arguments are also provided.
#' @param background_color Optional. Character string. CSS color for the card's background (e.g., "#f0f0f0", "white").
#'   Defaults to light gray. Overridden by `ressort_name` if not explicitly set.
#' @param text_color Optional. Character string. CSS color for the card's text (e.g., "#333333", "black").
#'   Defaults to dark gray. Overridden by `ressort_name` if not explicitly set.
#' @param border_color Optional. Character string. CSS color for the card's border (e.g., "#cccccc", "blue").
#'   Defaults to medium gray. Overridden by `ressort_name` (uses accent color) if not explicitly set.
#' @param border_gradient Optional. Character string. CSS gradient for the card's border.
#'   Only used if not NULL and not empty.
#' @param card_width Optional. Character string. CSS width for the card (e.g., "300px", "100%", "auto").
#'   Defaults to "min(100%, 350px)" which ensures the card is never wider than 350px but can shrink on smaller screens.
#' @param border_width Optional. Numeric. Width of the card's border in pixels. Defaults to 2.
#' @param font_family Optional. Character string. CSS `font-family` string for the card's text.
#'   Defaults to "STMatilda Text Variable, system-ui, serif".
#' @param main_value_font_size Optional. Character string. CSS `font-size` for the `main_value` (e.g., "3em", "48px"). Defaults to "3em".
#' @param main_text_font_size Optional. Character string. CSS `font-size` for the `main_text` (e.g., "1em", "16px"). Defaults to "1em".
#' @param shadow_intensity Optional. Character string. Controls the box shadow intensity.
#'   Valid values: "none", "low", "middle" (or "medium"), "intense" (or "high"). Defaults to "middle".
#'
#' @param # --- Formatting Parameters ---
#' @param number_format Optional. Character string. The locale to use for number formatting (e.g., "de-DE" for German format).
#'   If NULL, no specific formatting is applied. Common values: "de-DE" (German), "en-US" (US), "fr-FR" (French).
#'   Only applies when `animate_value` is TRUE.
#'
#' @importFrom htmltools htmlEscape tagList HTML
#' @importFrom glue glue
#' @export
html_create_info_card <- function(
  # --- Content Parameters ---
  main_value,
  main_text,
  headline = NULL,
  source_text = NULL,
  source_link = NULL,
  sr_only_main_value_label = NULL,
  show_percentage_sign = FALSE,
  # --- Animation Parameters ---
  animation_duration_ms = 1500, # Shared duration for all animations
  animation_trigger_threshold = 5, # Percentage above bottom to trigger animation
  animate_value = FALSE,
  animation_initial_display = "0",
  # --- Percentage Bar Parameters ---
  show_percentage_bar = FALSE,
  animate_percentage_bar = TRUE,
  percentage_bar_color = "rgba(0, 0, 0, 0.1)",
  # --- Styling Parameters ---
  ressort_name = NULL,
  background_color = "#f0f0f0",
  text_color = "#333333",
  border_color = "#cccccc",
  border_gradient = NULL,
  card_width = "100%",
  border_width = 2,
  font_family = "STMatilda Text Variable, system-ui, serif",
  main_value_font_size = "1.7em",
  main_text_font_size = "18px",
  shadow_intensity = "middle",
  # --- Formatting Parameters ---
  number_format = NULL
) {
  # Generate a random hash for unique class names
  card_hash <- paste0(
    "_",
    paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  )

  # Define class names with hash
  container_class <- paste0("dj-info-card-container", card_hash)
  sr_only_class <- paste0("dj-info-card-sr-only", card_hash)
  percentage_bar_class <- paste0("dj-info-card-percentage-bar", card_hash)
  content_class <- paste0("dj-info-card-content", card_hash)
  animated_number_class <- paste0("dj-info-card-animated-number", card_hash)
  headline_class <- paste0("info-card-headline", card_hash)
  source_class <- paste0("info-card-source", card_hash)
  main_value_wrapper_class <- paste0(
    "dj-info-card-main-value-wrapper",
    card_hash
  )
  main_text_class <- paste0("dj-info-card-main-text", card_hash)

  # --- Internal Helper Function for Animation Parsing ---
  .parse_value_for_animation <- function(
    value,
    initial_display_override = NULL,
    number_format = NULL
  ) {
    if (is.null(value)) {
      return(list(
        numeric_char = "0",
        final_value_attr = "0",
        initial_display_html = if (!is.null(initial_display_override)) {
          htmltools::htmlEscape(initial_display_override)
        } else {
          "0"
        },
        suffix = ""
      ))
    }

    # Handle numeric values
    if (is.numeric(value)) {
      # Convert to string with proper decimal point for JavaScript
      numeric_str <- format(value, scientific = FALSE, decimal.mark = ".")
      return(list(
        numeric_char = numeric_str,
        final_value_attr = numeric_str, # Final display is just the number
        initial_display_html = if (!is.null(initial_display_override)) {
          htmltools::htmlEscape(initial_display_override)
        } else {
          "0"
        },
        suffix = ""
      ))
    }

    # Handle character values
    if (!is.character(value) || !nzchar(trimws(value))) {
      return(list(
        numeric_char = "0",
        final_value_attr = "0",
        initial_display_html = if (!is.null(initial_display_override)) {
          htmltools::htmlEscape(initial_display_override)
        } else {
          "0"
        },
        suffix = ""
      ))
    }

    # For character values, try to parse as number
    final_value_for_attr <- htmltools::htmlEscape(value)
    initial_display_content <- if (!is.null(initial_display_override)) {
      initial_display_override
    } else {
      "0"
    }
    initial_display_html_escaped <- htmltools::htmlEscape(
      initial_display_content
    )

    # Try to parse the string as a number
    cleaned_s <- value

    # First, strip common non-numeric symbols that are not separators
    cleaned_s <- gsub("€|\\$|¥|£|%|\\+|°|C|F", "", cleaned_s)
    cleaned_s <- trimws(cleaned_s)

    # Use locale to correctly interpret comma and period
    if (!is.null(number_format) && number_format == "de-DE") {
      # German format: '.' is for thousands, ',' is for decimal.
      # Remove thousands separators, then convert decimal comma to dot.
      cleaned_s <- gsub("\\.", "", cleaned_s)
      cleaned_s <- gsub(",", ".", cleaned_s)
    } else {
      # Default/English format: ',' is for thousands, '.' is for decimal.
      # Remove thousands separators. Dot is already correct for decimal.
      cleaned_s <- gsub(",", "", cleaned_s)
    }

    # Final cleanup to ensure it's a valid number for JS
    cleaned_s <- gsub("[^0-9.-]", "", cleaned_s)

    numeric_target_val <- suppressWarnings(as.numeric(cleaned_s))
    numeric_char_for_data <- if (is.na(numeric_target_val)) {
      "0"
    } else {
      as.character(numeric_target_val)
    }

    suffix <- ""
    if (is.character(value)) {
      last_digit_indices <- gregexpr("[0-9]", value)
      if (
        length(last_digit_indices[[1]]) > 0 && last_digit_indices[[1]][1] != -1
      ) {
        last_digit_pos <- max(last_digit_indices[[1]])
        if (last_digit_pos < nchar(value)) {
          suffix <- substr(value, last_digit_pos + 1, nchar(value))
        }
      }
    }

    return(list(
      numeric_char = numeric_char_for_data,
      final_value_attr = final_value_for_attr,
      initial_display_html = initial_display_html_escaped,
      suffix = suffix
    ))
  }

  # --- Ressort Palettes, Color Determination, Shadow Style, Validations ---
  .ressort_palettes <- list(
    dst_apo = list(
      bg = "#c1d9d9",
      txt = "#2c3e50",
      acc1 = "#005A5B",
      acc2 = "#D9824A"
    ),
    dst_chripo = list(
      bg = "#d7e3e8",
      txt = "#34495e",
      acc1 = "#2980b9",
      acc2 = "#f39c12"
    ),
    dst_wirtschaft = list(
      bg = "#d8dec1",
      txt = "#3A3A3A",
      acc1 = "#006442",
      acc2 = "#A85A38"
    ),
    dst_pano_features = list(
      bg = "#aed4ae",
      txt = "#214022",
      acc1 = "#388E3C",
      acc2 = "#D4AC0D"
    ),
    dst_etat = list(
      bg = "#ffcc66",
      txt = "#4A3B06",
      acc1 = "#C0392b",
      acc2 = "#1A237E"
    ),
    dst_lifestyle = list(
      bg = "#ffffff",
      txt = "#333333",
      acc1 = "#E91E63",
      acc2 = "#009688"
    ),
    dst_karriere = list(
      bg = "#f8f8f8",
      txt = "#2c3e50",
      acc1 = "#3498db",
      acc2 = "#16a085"
    ),
    dst_wissenschaft = list(
      bg = "#bedae3",
      txt = "#1C3A50",
      acc1 = "#0D47A1",
      acc2 = "#FF6F00"
    )
  )
  for (name in names(.ressort_palettes)) {
    names(.ressort_palettes[[name]]) <- c(
      "background_color",
      "text_color",
      "accent_color_1",
      "accent_color_2"
    )
  }
  final_bg_color <- background_color
  final_text_color <- text_color
  final_border_color <- border_color
  if (!is.null(ressort_name) && nzchar(trimws(ressort_name))) {
    if (ressort_name %in% names(.ressort_palettes)) {
      selected_palette <- .ressort_palettes[[ressort_name]]
      fmls <- formals(html_create_info_card)
      if (identical(background_color, fmls$background_color)) {
        final_bg_color <- selected_palette$background_color
      }
      if (identical(text_color, fmls$text_color)) {
        final_text_color <- selected_palette$text_color
      }
      if (identical(border_color, fmls$border_color)) {
        final_border_color <- selected_palette$accent_color_1
      }
    } else {
      warning(glue::glue("Ressort name '{ressort_name}' not recognized."))
    }
  }
  box_shadow_style_value <- "none"
  valid_intensities <- c("none", "low", "middle", "medium", "intense", "high")
  shadow_intensity_lower <- tolower(trimws(shadow_intensity))
  if (shadow_intensity_lower %in% valid_intensities) {
    if (shadow_intensity_lower == "none") {
      box_shadow_style_value <- "none"
    } else if (shadow_intensity_lower %in% c("low")) {
      box_shadow_style_value <- "0 2px 4px rgba(0,0,0,0.08)"
    } else if (shadow_intensity_lower %in% c("middle", "medium")) {
      box_shadow_style_value <- "0 4px 8px rgba(0,0,0,0.12)"
    } else if (shadow_intensity_lower %in% c("intense", "high")) {
      box_shadow_style_value <- "0 8px 16px rgba(0,0,0,0.15), 0 3px 6px rgba(0,0,0,0.10)"
    }
  } else {
    warning(glue::glue(
      "Invalid `shadow_intensity`: '{shadow_intensity}'. Using 'none'."
    ))
    box_shadow_style_value <- "none"
  }
  box_shadow_css_property <- paste0("box-shadow: ", box_shadow_style_value, ";")
  if (
    !is.numeric(main_value) &&
      (!is.character(main_value) || nzchar(trimws(main_value)) == 0)
  ) {
    stop("`main_value` must be either a numeric value or a non-empty string.")
  }
  if (!is.character(main_text)) {
    stop("`main_text` must be a string.")
  }

  # --- Screen Reader Text and Main Value Span Setup ---
  # Format the number immediately if it's numeric
  if (is.numeric(main_value)) {
    display_content_for_number_span <- .format_number_r(
      main_value,
      number_format
    )
    # Add percentage sign if requested
    if (show_percentage_sign) {
      display_content_for_number_span <- paste0(
        display_content_for_number_span,
        " %"
      )
    }
    # Set screen reader text
    screen_reader_full_text <- paste0(
      display_content_for_number_span,
      if (
        !is.null(sr_only_main_value_label) && nzchar(sr_only_main_value_label)
      ) {
        paste(" ", htmltools::htmlEscape(sr_only_main_value_label))
      } else if (!is.null(main_text) && nzchar(main_text)) {
        paste(" ", htmltools::htmlEscape(main_text))
      } else {
        ""
      }
    )
  } else {
    display_content_for_number_span <- htmltools::htmlEscape(main_value)
    screen_reader_full_text <- paste0(
      display_content_for_number_span,
      if (
        !is.null(sr_only_main_value_label) && nzchar(sr_only_main_value_label)
      ) {
        paste(" ", htmltools::htmlEscape(sr_only_main_value_label))
      } else if (!is.null(main_text) && nzchar(main_text)) {
        paste(" ", htmltools::htmlEscape(main_text))
      } else {
        ""
      }
    )
  }

  number_span_final_attrs <- c('aria-hidden="true"')

  if (animate_value) {
    parsed_val_info <- .parse_value_for_animation(
      main_value,
      animation_initial_display,
      number_format
    )
    # Add % sign only if explicitly requested
    if (show_percentage_sign) {
      if (!endsWith(parsed_val_info$suffix, "%")) {
        parsed_val_info$suffix <- paste0(parsed_val_info$suffix, " %")
      }
      if (!endsWith(parsed_val_info$final_value_attr, "%")) {
        parsed_val_info$final_value_attr <- paste0(
          parsed_val_info$final_value_attr,
          " %"
        )
      }
    }

    parsed_val_info$initial_display_html <- paste0(
      parsed_val_info$initial_display_html,
      parsed_val_info$suffix
    )

    display_content_for_number_span <- parsed_val_info$initial_display_html
    data_attrs_for_animation <- glue::glue(
      'data-numeric-target="{parsed_val_info$numeric_char}" ',
      'data-final-value="{parsed_val_info$final_value_attr}" ',
      'data-animation-duration="{as.integer(animation_duration_ms)}" ',
      'data-number-format="{if(!is.null(number_format)) number_format else ""}"',
      'data-suffix="{htmltools::htmlEscape(parsed_val_info$suffix)}"'
    )
    number_span_final_attrs <- c(
      number_span_final_attrs,
      data_attrs_for_animation
    )
  }
  number_span_attributes_as_string <- paste(
    number_span_final_attrs,
    collapse = " "
  )

  # --- HTML Elements Construction (headline, source) ---
  headline_html <- ""
  source_html <- ""
  if (!is.null(headline) && nzchar(trimws(headline))) {
    headline_html <- glue::glue(
      '<div class="{headline_class}" style="font-size: 1.1em; font-weight: 600; margin-bottom: 10px; color: {final_text_color};">{htmltools::htmlEscape(headline)}</div>'
    )
  }
  if (!is.null(source_text) && nzchar(trimws(source_text))) {
    st <- htmltools::htmlEscape(source_text)
    sc <- if (!is.null(source_link) && nzchar(trimws(source_link))) {
      glue::glue(
        '<a href="{htmltools::htmlEscape(source_link)}" target="_blank" style="color: {final_text_color}; text-decoration: underline;">{st}</a>'
      )
    } else {
      st
    }
    source_html <- glue::glue(
      '<div class="{source_class}" style="font-size: 0.8em; color: {final_text_color}; margin-top: 15px; opacity: 0.8;">Quelle: {sc}</div>'
    )
  }

  # --- Gradient Border Logic ---
  use_gradient_border <- !is.null(border_gradient) &&
    nzchar(trimws(border_gradient))
  container_extra_styles <- ""
  pseudo_element_css <- ""

  if (use_gradient_border) {
    # For a gradient border, the element's own border must be transparent
    # to let the pseudo-element's gradient background show through.
    final_border_color <- "transparent"
    container_extra_styles <- "background-clip: padding-box;"

    pseudo_element_css <- glue::glue(
      "
      .{container_class}::before {{
        content: '';
        position: absolute;
        top: 0; right: 0; bottom: 0; left: 0;
        z-index: -1;
        margin: -{border_width}px; /* Make pseudo-element bigger than container */
        border-radius: inherit; /* Match the parent's border-radius */
        background: {border_gradient};
      }}
      "
    )
  }

  # --- CSS Styles ---
  css_styles <- glue::glue(
    "
    .{container_class} {{
      box-sizing: border-box;
      margin: 15px auto;
      padding: 20px;
      background-color: {final_bg_color};
      color: {final_text_color};
      border: {border_width}px solid {final_border_color};
      border-radius: 8px;
      font-family: {font_family};
      text-align: center;
      {box_shadow_css_property}
      position: relative;
      width: {card_width};
      {container_extra_styles}
    }}
    {pseudo_element_css}
    .{sr_only_class} {{
      clip: rect(0 0 0 0);
      clip-path: inset(50%);
      height: 1px;
      overflow: hidden;
      position: absolute;
      white-space: nowrap;
      width: 1px;
    }}
    .{percentage_bar_class} {{
      position: absolute;
      top: 0;
      left: 0;
      height: 100%;
      background-color: {percentage_bar_color};
      width: 100%;
      transform: scaleX({if(show_percentage_bar && !animate_percentage_bar) as.numeric(main_value)/100 else '0'});
      transform-origin: left;
      {if(animate_percentage_bar) glue::glue('transition: transform {animation_duration_ms}ms cubic-bezier(0.4, 0, 0.2, 1);') else ''}
      will-change: transform;
      z-index: 0;
      border-radius: 6px;
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
      opacity: 1;
    }}
    .{content_class} {{
      position: relative;
      z-index: 1;
      will-change: transform;
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
    }}
    .{animated_number_class} {{
      display: inline-block;
      font-variant-numeric: tabular-nums;
      will-change: transform;
      transform: translateZ(0);
      -webkit-transform: translateZ(0);
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
    }}
  "
  )

  # --- JavaScript for Animation ---
  script_html <- ""

  # Only include JavaScript if we need animation or dynamic formatting
  if (animate_value || (show_percentage_bar && animate_percentage_bar)) {
    script_id <- paste0("infoCardAnimatorScript_", card_hash)

    # Combined animation and formatting script
    animation_js <- glue::glue(
      '
      <script id="{script_id}">
      (function() {{
        if (typeof window.initializeInfoCardAnimators === "function") {{
          // If already defined, re-initialize for any new cards.
          if (document.readyState === "loading") {{
            document.addEventListener("DOMContentLoaded", window.initializeInfoCardAnimators);
          }} else {{
            window.initializeInfoCardAnimators();
          }}
          return; // Avoid redefining the function
        }}

        window.initializeInfoCardAnimators = function() {{
          const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
          const prefersReducedMotion = mediaQuery.matches;

          function animateNumber(el) {{
            const targetStr = el.dataset.numericTarget;
            const target = parseFloat(targetStr);
            const duration = parseInt(el.dataset.animationDuration, 10) || {animation_duration_ms};
            const locale = el.dataset.numberFormat || undefined;
            const finalDisplay = el.dataset.finalValue;
            const suffix = el.dataset.suffix || "";

            if (isNaN(target)) {{
                el.textContent = finalDisplay;
                return;
            }}

            const decimalPlaces = (targetStr.includes(".")) ? targetStr.split(".")[1].length : 0;

            const numberFormatter = locale ? new Intl.NumberFormat(locale, {{
              minimumFractionDigits: decimalPlaces,
              maximumFractionDigits: decimalPlaces
            }}) : null;
            let startValue = 0; // Always start from 0 for simplicity
            let startTime = null;

            function animationStep(currentTime) {{
              if (!startTime) startTime = currentTime;
              const progress = Math.min((currentTime - startTime) / duration, 1);
              const currentValue = startValue + progress * (target - startValue);
              let displayedValue;

              if (numberFormatter) {{
                displayedValue = numberFormatter.format(currentValue);
              }} else {{
                // Fallback for no locale, round to the correct number of decimal places
                displayedValue = currentValue.toFixed(decimalPlaces);
              }}

              el.textContent = displayedValue + suffix;

              if (progress < 1) {{
                requestAnimationFrame(animationStep);
              }} else {{
                el.textContent = finalDisplay;
              }}
            }}

            requestAnimationFrame(animationStep);
          }}

          function animateBar(card) {{
            const bar = card.querySelector(".{percentage_bar_class}");
            if (!bar) return;

            const value = parseFloat(card.querySelector(".{animated_number_class}")?.dataset.numericTarget) || 0;
            const duration = {animation_duration_ms};

            bar.style.transition = "none";
            bar.style.transform = "scaleX(0)";
            bar.offsetHeight; // Force reflow

            requestAnimationFrame(() => {{
              bar.style.transition = `transform ${{duration}}ms cubic-bezier(0.4, 0, 0.2, 1)`;
              bar.style.transform = `scaleX(${{min(100, max(0, value)) / 100}})`;
            }});
          }}

          const observerOptions = {{
            root: null,
            rootMargin: "-{animation_trigger_threshold}% 0px",
            threshold: 0.1
          }};

          const observer = new IntersectionObserver((entries, obs) => {{
            entries.forEach(entry => {{
              if (entry.isIntersecting) {{
                const card = entry.target;
                if (card.dataset.animatedOnce === "true") return;
                card.dataset.animatedOnce = "true";

                // Animate number if requested
                const numberEl = card.querySelector(".{animated_number_class}");
                if ({tolower(animate_value)} && numberEl && numberEl.dataset.numericTarget) {{
                  animateNumber(numberEl);
                }}

                // Animate bar if requested
                if ({tolower(show_percentage_bar && animate_percentage_bar)}) {{
                  animateBar(card);
                }}

                obs.unobserve(card);
              }}
            }});
          }}, observerOptions);

          const cards = document.querySelectorAll(".{container_class}");
          cards.forEach(card => {{
            if (prefersReducedMotion) {{
              // If reduced motion is preferred, just show the final state.
              const numberEl = card.querySelector(".{animated_number_class}");
              if (numberEl) numberEl.textContent = numberEl.dataset.finalValue;

              const bar = card.querySelector(".{percentage_bar_class}");
              if (bar) {{
                const value = parseFloat(numberEl?.dataset.numericTarget) || 0;
                bar.style.transform = `scaleX(${{min(100, max(0, value)) / 100}})`;
              }}
              card.dataset.animatedOnce = "true";
            }} else {{
              observer.observe(card);
            }}
          }});
        }};

        if (document.readyState === "loading") {{
          document.addEventListener("DOMContentLoaded", window.initializeInfoCardAnimators);
        }} else {{
          window.initializeInfoCardAnimators();
        }}
      }})();
      </script>
    '
    )
    script_html <- animation_js
  }

  # --- Main HTML Output ---
  main_div_style_attributes <- c(
    paste0("background-color: ", final_bg_color, ";"),
    paste0("color: ", final_text_color, ";"),
    paste0("border: ", border_width, "px solid ", final_border_color, ";"),
    paste0("font-family: ", font_family, ";"),
    box_shadow_css_property
  )
  main_div_style_string <- paste(main_div_style_attributes, collapse = " ")

  # Create percentage bar HTML if needed
  percentage_bar_html <- if (show_percentage_bar) {
    glue::glue('<div class="{percentage_bar_class}"></div>')
  } else {
    ""
  }

  html_output <- glue::glue(
    '
    <style>
      {css_styles}
    </style>
    <div class="{container_class}" style="{main_div_style_string}">
      {percentage_bar_html}
      <div class="{content_class}">
        {headline_html}
        <div class="{main_value_wrapper_class}" style="font-size: {main_value_font_size}; font-weight: bold; line-height: 1.1; margin-bottom: 5px; color: {final_text_color};">
          <span class="{sr_only_class}">{screen_reader_full_text}</span>
          <span class="{animated_number_class}" {number_span_attributes_as_string}>
            {display_content_for_number_span}
          </span>
        </div>
        <div class="{main_text_class}"
             style="font-size: {main_text_font_size};
                    line-height: 1.4;
                    color: {final_text_color};
                    opacity: 0.9;">
          {htmltools::htmlEscape(main_text)}
        </div>
        {source_html}
      </div>
    </div>
    {script_html}
  '
  )

  return(htmltools::HTML(html_output))
}

# Helper function for number formatting
.format_number_r <- function(value, locale = NULL) {
  if (!is.numeric(value)) {
    return(as.character(value))
  }

  if (!is.null(locale)) {
    # Use the same formatting as the JavaScript Intl.NumberFormat
    if (locale == "de-DE") {
      return(format(
        value,
        big.mark = ".",
        decimal.mark = ",",
        scientific = FALSE
      ))
    } else {
      return(format(
        value,
        big.mark = ",",
        decimal.mark = ".",
        scientific = FALSE
      ))
    }
  }

  # Default formatting
  return(format(value, big.mark = ",", decimal.mark = ".", scientific = FALSE))
}
