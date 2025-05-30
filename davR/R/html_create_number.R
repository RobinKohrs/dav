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
html_create_info_card = function(
    # --- Content Parameters ---
    main_value,
    main_text,
    headline = NULL,
    source_text = NULL,
    source_link = NULL,
    sr_only_main_value_label = NULL,
    show_percentage_sign = FALSE,

    # --- Animation Parameters ---
    animation_duration_ms = 1500,      # Shared duration for all animations
    animation_trigger_threshold = 5,   # Percentage above bottom to trigger animation
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
  card_hash <- paste0("_", paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = ""))
  
  # Define class names with hash
  container_class <- paste0("dj-info-card-container", card_hash)
  sr_only_class <- paste0("dj-info-card-sr-only", card_hash)
  percentage_bar_class <- paste0("dj-info-card-percentage-bar", card_hash)
  content_class <- paste0("dj-info-card-content", card_hash)
  animated_number_class <- paste0("dj-info-card-animated-number", card_hash)
  headline_class <- paste0("info-card-headline", card_hash)
  source_class <- paste0("info-card-source", card_hash)
  main_value_wrapper_class <- paste0("dj-info-card-main-value-wrapper", card_hash)
  main_text_class <- paste0("dj-info-card-main-text", card_hash)

  # --- Internal Helper Function for Animation Parsing ---
  .parse_value_for_animation <- function(value, initial_display_override = NULL) {
    if (is.null(value)) {
      return(list(numeric_char = "0",
                  final_value_attr = "0",
                  initial_display_html = if(!is.null(initial_display_override)) htmltools::htmlEscape(initial_display_override) else "0"))
    }

    # Handle numeric values
    if (is.numeric(value)) {
      # Convert to string with proper decimal point for JavaScript
      numeric_str <- format(value, scientific = FALSE, decimal.mark = ".")
      # Add % sign for display if the value is between 0 and 100
      display_str <- if (value >= 0 && value <= 100) {
        paste0(numeric_str, " %")
      } else {
        numeric_str
      }
      return(list(
        numeric_char = numeric_str,
        final_value_attr = display_str,  # Include % sign in the final display
        initial_display_html = if(!is.null(initial_display_override)) htmltools::htmlEscape(initial_display_override) else "0 %"
      ))
    }

    # Handle character values
    if (!is.character(value) || !nzchar(trimws(value))) {
      return(list(numeric_char = "0",
                  final_value_attr = "0 %",
                  initial_display_html = if(!is.null(initial_display_override)) htmltools::htmlEscape(initial_display_override) else "0 %"))
    }

    # For character values, try to parse as number
    final_value_for_attr <- htmltools::htmlEscape(value)
    initial_display_content <- if(!is.null(initial_display_override)) initial_display_override else "0 %"
    initial_display_html_escaped <- htmltools::htmlEscape(initial_display_content)

    # Try to parse the string as a number
    s <- value
    s_numeric_parse <- gsub("€|\\$|¥|£", "", s)
    s_numeric_parse <- gsub("%|\\+", "", s_numeric_parse)
    s_numeric_parse <- trimws(s_numeric_parse)

    if (grepl("^[0-9]{1,3}(\\.[0-9]{3})*(,[0-9]+)?$", s_numeric_parse)) {
      cleaned_s <- gsub("\\.", "", s_numeric_parse)
      cleaned_s <- gsub(",", ".", cleaned_s)
    } else if (grepl("^[0-9]{1,3}(,[0-9]{3})*(\\.[0-9]+)?$", s_numeric_parse)) {
      cleaned_s <- gsub(",", "", s_numeric_parse)
    } else if (grepl("^[0-9]+(\\.[0-9]{3})*$", s_numeric_parse) && grepl("\\.", s_numeric_parse) && !grepl(",[0-9]", s_numeric_parse)) {
      cleaned_s <- gsub("\\.", "", s_numeric_parse)
    } else {
      cleaned_s <- s_numeric_parse
    }

    cleaned_s <- gsub("[^0-9.-]", "", cleaned_s)
    if (length(gregexpr("\\.", cleaned_s)[[1]]) > 1) {
      parts <- strsplit(cleaned_s, "\\.")[[1]]
      cleaned_s <- paste0(parts[1], if(length(parts)>1) paste0(".", paste(parts[-1], collapse="")) else "")
    }
    if (length(gregexpr("-", cleaned_s)[[1]]) > 1 || (length(gregexpr("-", cleaned_s)[[1]]) == 1 && regexpr("-", cleaned_s)[1] > 1)) {
      cleaned_s <- gsub("-", "", cleaned_s)
    }

    numeric_target_val <- suppressWarnings(as.numeric(cleaned_s))
    numeric_char_for_data <- if(is.na(numeric_target_val)) "0" else as.character(numeric_target_val)

    # Add % sign for display if the value is between 0 and 100
    final_display <- if (!is.na(numeric_target_val) && numeric_target_val >= 0 && numeric_target_val <= 100) {
      paste0(final_value_for_attr, " %")
    } else {
      final_value_for_attr
    }

    return(list(
      numeric_char = numeric_char_for_data,
      final_value_attr = final_display,
      initial_display_html = initial_display_html_escaped
    ))
  }

  # --- Ressort Palettes, Color Determination, Shadow Style, Validations ---
  .ressort_palettes <- list(dst_apo = list(bg="#c1d9d9", txt="#2c3e50", acc1="#005A5B", acc2="#D9824A"), dst_chripo = list(bg="#d7e3e8", txt="#34495e", acc1="#2980b9", acc2="#f39c12"), dst_wirtschaft = list(bg="#d8dec1", txt="#3A3A3A", acc1="#006442", acc2="#A85A38"), dst_pano_features = list(bg="#aed4ae", txt="#214022", acc1="#388E3C", acc2="#D4AC0D"), dst_etat = list(bg="#ffcc66", txt="#4A3B06", acc1="#C0392b", acc2="#1A237E"), dst_lifestyle = list(bg="#ffffff", txt="#333333", acc1="#E91E63", acc2="#009688"), dst_karriere = list(bg="#f8f8f8", txt="#2c3e50", acc1="#3498db", acc2="#16a085"), dst_wissenschaft = list(bg="#bedae3", txt="#1C3A50", acc1="#0D47A1", acc2="#FF6F00"));
  for(name in names(.ressort_palettes)) { names(.ressort_palettes[[name]]) <- c("background_color", "text_color", "accent_color_1", "accent_color_2")}
  final_bg_color <- background_color; final_text_color <- text_color; final_border_color <- border_color;
  if (!is.null(ressort_name) && nzchar(trimws(ressort_name))) { if (ressort_name %in% names(.ressort_palettes)) { selected_palette <- .ressort_palettes[[ressort_name]]; fmls <- formals(html_create_info_card); if (identical(background_color, fmls$background_color)) final_bg_color <- selected_palette$background_color; if (identical(text_color, fmls$text_color)) final_text_color <- selected_palette$text_color; if (identical(border_color, fmls$border_color)) final_border_color <- selected_palette$accent_color_1; } else { warning(glue::glue("Ressort name '{ressort_name}' not recognized."))}}
  box_shadow_style_value <- "none"; valid_intensities <- c("none", "low", "middle", "medium", "intense", "high"); shadow_intensity_lower <- tolower(trimws(shadow_intensity));
  if (shadow_intensity_lower %in% valid_intensities) { if (shadow_intensity_lower == "none") {box_shadow_style_value <- "none"} else if (shadow_intensity_lower %in% c("low")) {box_shadow_style_value <- "0 2px 4px rgba(0,0,0,0.08)"} else if (shadow_intensity_lower %in% c("middle", "medium")) {box_shadow_style_value <- "0 4px 8px rgba(0,0,0,0.12)"} else if (shadow_intensity_lower %in% c("intense", "high")) {box_shadow_style_value <- "0 8px 16px rgba(0,0,0,0.15), 0 3px 6px rgba(0,0,0,0.10)"}} else { warning(glue::glue("Invalid `shadow_intensity`: '{shadow_intensity}'. Using 'none'.")); box_shadow_style_value <- "none"}
  box_shadow_css_property <- paste0("box-shadow: ", box_shadow_style_value, ";");
  if (!is.numeric(main_value) && (!is.character(main_value) || nzchar(trimws(main_value)) == 0)) {
    stop("`main_value` must be either a numeric value or a non-empty string.")
  }
  if (!is.character(main_text)) stop("`main_text` must be a string.")


  # --- Screen Reader Text and Main Value Span Setup ---
  # Format the number immediately if it's numeric
  if (is.numeric(main_value)) {
    display_content_for_number_span <- .format_number_r(main_value, number_format)
    # Add percentage sign if requested
    if (show_percentage_sign) {
      display_content_for_number_span <- paste0(display_content_for_number_span, " %")
    }
    # Set screen reader text
    screen_reader_full_text <- paste0(display_content_for_number_span, 
      if (!is.null(sr_only_main_value_label) && nzchar(sr_only_main_value_label)) {
        paste(" ", htmltools::htmlEscape(sr_only_main_value_label))
      } else if (!is.null(main_text) && nzchar(main_text)) {
        paste(" ", htmltools::htmlEscape(main_text))
      } else {
        ""
      }
    )
  } else {
    display_content_for_number_span <- htmltools::htmlEscape(main_value)
    screen_reader_full_text <- paste0(display_content_for_number_span,
      if (!is.null(sr_only_main_value_label) && nzchar(sr_only_main_value_label)) {
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
    parsed_val_info <- .parse_value_for_animation(main_value, animation_initial_display)
    # Add % sign only if explicitly requested
    if (show_percentage_sign) {
      parsed_val_info$final_value_attr <- paste0(parsed_val_info$final_value_attr, " %")
      parsed_val_info$initial_display_html <- paste0(parsed_val_info$initial_display_html, " %")
    }
    display_content_for_number_span <- parsed_val_info$initial_display_html
    data_attrs_for_animation <- glue::glue(
      'data-numeric-target="{parsed_val_info$numeric_char}" ',
      'data-final-value="{parsed_val_info$final_value_attr}" ',
      'data-animation-duration="{as.integer(animation_duration_ms)}" ',
      'data-number-format="{if(!is.null(number_format)) number_format else ""}"'
    )
    number_span_final_attrs <- c(number_span_final_attrs, data_attrs_for_animation)
  }
  number_span_attributes_as_string <- paste(number_span_final_attrs, collapse = " ")

  # --- HTML Elements Construction (headline, source) ---
  headline_html <- ""; source_html <- ""
  if (!is.null(headline) && nzchar(trimws(headline))) {
    headline_html <- glue::glue('<div class="{headline_class}" style="font-size: 1.1em; font-weight: 600; margin-bottom: 10px; color: {final_text_color};">{htmltools::htmlEscape(headline)}</div>')
  }
  if (!is.null(source_text) && nzchar(trimws(source_text))) {
    st <- htmltools::htmlEscape(source_text); sc <- if (!is.null(source_link) && nzchar(trimws(source_link))) glue::glue('<a href="{htmltools::htmlEscape(source_link)}" target="_blank" style="color: {final_text_color}; text-decoration: underline;">{st}</a>') else st; source_html <- glue::glue('<div class="{source_class}" style="font-size: 0.8em; color: {final_text_color}; margin-top: 15px; opacity: 0.8;">Quelle: {sc}</div>')
  }

  # --- CSS Styles ---
  css_styles <- glue::glue("
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
      {card_width}
    }}
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
      will-change: transform;
      transform: translateZ(0);
      -webkit-transform: translateZ(0);
      backface-visibility: hidden;
      -webkit-backface-visibility: hidden;
    }}
  ")

  # --- JavaScript for Animation ---
  script_html <- ""
  
  # Only include JavaScript if we need animation or dynamic formatting
  if (animate_value || (show_percentage_bar && animate_percentage_bar)) {
    script_id <- paste0("infoCardAnimatorScript_", card_hash)
    number_format_js <- if (!is.null(number_format)) {
      glue::glue('
        // Cache the number formatter
        const numberFormat = new Intl.NumberFormat("{number_format}", {{
          minimumFractionDigits: 0,
          maximumFractionDigits: 2,
          useGrouping: true,
          style: "decimal"
        }});

        // Cache DOM queries
        let cachedElements = null;
        function getElements() {{
          if (!cachedElements) {{
            cachedElements = document.querySelectorAll(".{animated_number_class}");
          }}
          return cachedElements;
        }}

        // Format both the initial and final values immediately
        function formatInitialValue() {{
          const elements = getElements();
          const len = elements.length;
          for (let i = 0; i < len; i++) {{
            const el = elements[i];
            const value = el.textContent;
            const numericValue = parseFloat(value);
            if (!isNaN(numericValue)) {{
              el.textContent = numberFormat.format(numericValue) + ({tolower(show_percentage_sign)} ? " %" : "");
            }}
          }}
        }}

        // Format all numbers immediately and on page load
        formatInitialValue();
        document.addEventListener("DOMContentLoaded", formatInitialValue);
      ')
    } else {
      glue::glue('
        // Cache DOM queries
        let cachedElements = null;
        function getElements() {{
          if (!cachedElements) {{
            cachedElements = document.querySelectorAll(".{animated_number_class}");
          }}
          return cachedElements;
        }}

        function formatInitialValue() {{
          const elements = getElements();
          const len = elements.length;
          for (let i = 0; i < len; i++) {{
            const el = elements[i];
            const value = el.textContent;
            const numericValue = parseFloat(value);
            if (!isNaN(numericValue)) {{
              el.textContent = numericValue.toLocaleString() + ({tolower(show_percentage_sign)} ? " %" : "");
            }}
          }}
        }}

        // Format all numbers immediately and on page load
        formatInitialValue();
        document.addEventListener("DOMContentLoaded", formatInitialValue);
      ')
    }

    script_html <- glue::glue("
      <script id='{script_id}'>
      (function() {{
        {number_format_js}
      }})();
      </script>
    ")

    # Add animation JavaScript if needed
    if (show_percentage_bar && animate_percentage_bar) {
      animation_js <- glue::glue('
        if (typeof window.initializeInfoCardAnimators !== "function") {{
          window.initializeInfoCardAnimators = function() {{
            const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
            const prefersReducedMotion = mediaQuery.matches;

            // Get all cards with percentage bars
            const cards = document.querySelectorAll(".{container_class}:has(.{percentage_bar_class})");
            if (!cards.length) return;

            function animateBar(card, value, duration, shouldAnimate) {{
              const bar = card.querySelector(".{percentage_bar_class}");
              if (!bar) return;

              if (!shouldAnimate) {{
                // Set final state immediately without animation
                bar.style.transition = "none";
                bar.style.transform = `scaleX(${{Math.min(value, 100) / 100}})`;
                bar.offsetHeight; // Force reflow
                bar.style.transition = "";
                return;
              }}

              // Reset the bar
              bar.style.transition = "none";
              bar.style.transform = "scaleX(0)";
              bar.offsetHeight; // Force reflow

              // Start animation
              requestAnimationFrame(() => {{
                bar.style.transition = `transform ${{duration}}ms cubic-bezier(0.4, 0, 0.2, 1)`;
                bar.style.transform = `scaleX(${{Math.min(value, 100) / 100}})`;
              }});
            }}

            let observer = null;
            if (!prefersReducedMotion) {{
              const observerOptions = {{
                root: null,
                rootMargin: "-{animation_trigger_threshold}% 0px",
                threshold: [0.5, 0.75]
              }};
              observer = new IntersectionObserver((entries) => {{
                entries.forEach(entry => {{
                  if (entry.isIntersecting && entry.intersectionRatio >= 0.5) {{
                    const card = entry.target;
                    if (card.dataset.animatedOnce === "true") return;
                    card.dataset.animatedOnce = "true";

                    const numberEl = card.querySelector(".{animated_number_class}");
                    const value = numberEl ? parseFloat(numberEl.textContent) || 0 : 0;

                    setTimeout(() => {{
                      animateBar(card, value, {animation_duration_ms}, {tolower(animate_percentage_bar)});
                    }}, 100);

                    observer.unobserve(card);
                  }}
                }});
              }}, observerOptions);
            }}

            const len = cards.length;
            for (let i = 0; i < len; i++) {{
              const card = cards[i];
              if (prefersReducedMotion) {{
                const numberEl = card.querySelector(".{animated_number_class}");
                const value = numberEl ? parseFloat(numberEl.textContent) || 0 : 0;
                animateBar(card, value, 0, {tolower(animate_percentage_bar)});
                card.dataset.animatedOnce = "true";
              }} else if (observer) {{
                observer.observe(card);
              }} else {{
                const numberEl = card.querySelector(".{animated_number_class}");
                const value = numberEl ? parseFloat(numberEl.textContent) || 0 : 0;
                animateBar(card, value, {animation_duration_ms}, {tolower(animate_percentage_bar)});
                card.dataset.animatedOnce = "true";
              }}
            }}
          }};

          if (document.readyState === "loading") {{
            document.addEventListener("DOMContentLoaded", window.initializeInfoCardAnimators);
          }} else {{
            window.initializeInfoCardAnimators();
          }}
        }} else {{
          if (document.readyState === "loading") {{
            document.addEventListener("DOMContentLoaded", window.initializeInfoCardAnimators);
          }} else {{
            window.initializeInfoCardAnimators();
          }}
        }}
      ')

      script_html <- paste0(script_html, "\n<script>", animation_js, "</script>")
    }
  }

  # --- Main HTML Output ---
  main_div_style_attributes <- c(
    paste0("background-color: ", final_bg_color, ";"),
    paste0("color: ", final_text_color, ";"),
    paste0("border: ", border_width, "px solid ", final_border_color, ";"),
    paste0("font-family: ", font_family, ";"),
    box_shadow_css_property
  );
  main_div_style_string <- paste(main_div_style_attributes, collapse = " ");

  # Create percentage bar HTML if needed
  percentage_bar_html <- if (show_percentage_bar) {
    glue::glue('<div class="{percentage_bar_class}"></div>')
  } else {
    ''
  }

  html_output = glue::glue('
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
  ')

  return(htmltools::HTML(html_output))
}

# Helper function for number formatting
.format_number_r <- function(value, locale = NULL) {
  if (!is.numeric(value)) return(as.character(value))

  if (!is.null(locale)) {
    # Use the same formatting as the JavaScript Intl.NumberFormat
    if (locale == "de-DE") {
      return(format(value, big.mark = ".", decimal.mark = ",", scientific = FALSE))
    } else {
      return(format(value, big.mark = ",", decimal.mark = ".", scientific = FALSE))
    }
  }

  # Default formatting
  return(format(value, big.mark = ",", decimal.mark = ".", scientific = FALSE))
}
