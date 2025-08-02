#' Create an HTML Image Comparison Slider
#'
#' Generates HTML, CSS, and JavaScript for a responsive image comparison slider.
#' Users can slide a divider to reveal more or less of two juxtaposed images.
#' The slider interacts with mouse hover and touch-drag movements.
#' All generated CSS classes and the main element ID are prefixed with "dj-"
#' for better namespacing in CMS environments.
#'
#' @param # --- Content Parameters ---
#' @param image_left_url Character string. URL for the "left" or "before" image. (Required)
#' @param image_right_url Character string. URL for the "right" or "after" image. (Required)
#' @param alt_left_image Character string. Alt text for the left image for accessibility.
#'   Defaults to "Left image".
#' @param alt_right_image Character string. Alt text for the right image for accessibility.
#'   Defaults to "Right image".
#' @param label_left Optional. Character string. A label displayed on the left image (e.g., "Before").
#' @param label_right Optional. Character string. A label displayed on the right image (e.g., "After").
#'
#' @param # --- Behavior Parameters ---
#' @param initial_slider_position_percent Numeric (0-100). Initial position of the slider divider.
#'   Defaults to 50 (centered).
#' @param slide_on_hover Logical. If TRUE, the slider divider follows the mouse cursor when hovering
#'   over the component. Defaults to TRUE.
#' @param enable_drag Logical. If TRUE, the slider can be explicitly dragged with a mouse click or touch.
#'   Defaults to TRUE.
#'
#' @param # --- Styling Parameters ---
#' @param container_width Character string. CSS width for the slider container (e.g., "500px", "100%").
#'   Defaults to "100%". Note: The actual width will be constrained to max-width: 615px.
#' @param container_height Character string. CSS height for the slider container.
#'   If "auto", height will be determined by the 16:9 aspect ratio.
#'   It's recommended to use images with the same aspect ratio. Defaults to "auto".
#' @param handle_line_color Character string. CSS color for the slider's dividing line.
#'   Defaults to "rgba(255, 255, 255, 0.9)".
#' @param handle_grip_color Character string. CSS color for the slider's circular drag grip.
#'   Defaults to "#ffffff".
#' @param handle_arrow_color Character string. CSS color for the arrows inside the drag grip.
#'   Defaults to "#333333".
#' @param handle_line_width Numeric. Width of the dividing line in pixels. Defaults to 2.
#' @param handle_grip_size Numeric. Diameter of the circular grip in pixels. Defaults to 40.
#' @param label_font_family Character string. CSS `font-family` for labels. Defaults to "system-ui, sans-serif".
#' @param label_font_size Character string. CSS `font-size` for labels. Defaults to "0.9em".
#' @param label_text_color Character string. CSS color for label text. Defaults to "white".
#' @param label_background_color Character string. CSS `background-color` for labels.
#'   Defaults to "rgba(0, 0, 0, 0.6)".
#' @param label_padding Character string. CSS padding for labels (e.g., "5px 10px"). Defaults to "5px 10px".
#' @param border_radius Character string. CSS `border-radius` for the main container. Defaults to "8px".
#' @param show_labels_on_hover Logical. If TRUE, labels are only visible when hovering over the slider.
#'   Defaults to FALSE (always visible if provided).
#'
#' @param # --- Accessibility Parameters ---
#' @param slider_aria_label Character string. ARIA label for the slider functionality, for screen readers.
#'  Defaults to "Image comparison slider".
#' @param label_position Character string. Position of the labels: "bottom" (default) or "top".
#'
#' @importFrom htmltools htmlEscape HTML
#' @importFrom glue glue
#' @importFrom jsonlite toJSON
#' @export
html_create_image_slider <- function(
  # --- Content Parameters ---
  image_left_url,
  image_right_url,
  alt_left_image = "Left image",
  alt_right_image = "Right image",
  label_left = NULL,
  label_right = NULL,

  # --- Behavior Parameters ---
  initial_slider_position_percent = 50,
  slide_on_hover = TRUE,
  enable_drag = TRUE,

  # --- Styling Parameters ---
  container_width = "100%",
  container_height = "auto",
  handle_line_color = "rgba(255, 255, 255, 0.9)",
  handle_grip_color = "#ffffff",
  handle_arrow_color = "#333333",
  handle_line_width = 2,
  handle_grip_size = 40,
  label_font_family = "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif",
  label_font_size = "0.9em",
  label_text_color = "white",
  label_background_color = "rgba(0, 0, 0, 0.6)",
  label_padding = "5px 10px",
  border_radius = "8px",
  show_labels_on_hover = FALSE,

  # --- Accessibility Parameters ---
  slider_aria_label = "Image comparison slider",
  # --- New Parameter ---
  label_position = "bottom"
) {
  # --- Input Validations ---
  if (
    missing(image_left_url) ||
      !is.character(image_left_url) ||
      nzchar(trimws(image_left_url)) == 0
  ) {
    stop("`image_left_url` must be a non-empty string.")
  }
  if (
    missing(image_right_url) ||
      !is.character(image_right_url) ||
      nzchar(trimws(image_right_url)) == 0
  ) {
    stop("`image_right_url` must be a non-empty string.")
  }
  if (
    !is.numeric(initial_slider_position_percent) ||
      initial_slider_position_percent < 0 ||
      initial_slider_position_percent > 100
  ) {
    warning(
      "`initial_slider_position_percent` should be between 0 and 100. Clamping to nearest valid value."
    )
    initial_slider_position_percent <- max(
      0,
      min(100, initial_slider_position_percent)
    )
  }
  if (!label_position %in% c("bottom", "top")) {
    stop("`label_position` must be either 'bottom' or 'top'.")
  }

  # --- Generate Unique ID for the slider instance with "dj-" prefix ---
  unique_suffix <- paste0(
    sample(c(letters, 0:9), 12, replace = TRUE),
    collapse = ""
  )
  slider_id <- paste0("dj-image-slider-", unique_suffix)
  script_tag_id <- paste0("djImageSliderScript_", unique_suffix) # Consistent with info_card

  # --- CSS Styles (with "dj-image-slider-" prefix) ---
  css_styles <- glue::glue(
    "
    .dj-image-slider-container {{
      box-sizing: border-box;
      position: relative;
      overflow: hidden;
      cursor: default;
      touch-action: none;
      -webkit-user-select: none;
      -ms-user-select: none;
      user-select: none;
      width: {container_width};
      max-width: 615px;
      margin: 0 auto;
      border-radius: {border_radius};
      background-color: #f0f0f0;
    }}
    .dj-image-slider-container * {{
      box-sizing: border-box;
    }}
    .dj-image-slider-img-wrapper {{
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
    }}
    .dj-image-slider-img-wrapper.dj-image-slider-left-wrapper {{
      z-index: 1;
    }}
    .dj-image-slider-img-wrapper.dj-image-slider-right-wrapper {{
      z-index: 0;
    }}
    .dj-image-slider-img {{
      position: absolute;
      width: 100%;
      height: auto;
      display: block;
      pointer-events: none;
    }}
    .dj-image-slider-handle {{
      position: absolute;
      top: 0;
      height: 100%;
      width: {handle_line_width}px;
      background-color: {handle_line_color};
      z-index: 3;
      cursor: ew-resize;
      display: flex;
      align-items: center;
      justify-content: center;
      transform: translateX(-50%);
    }}
    .dj-image-slider-handle-grip {{
      width: {handle_grip_size}px;
      height: {handle_grip_size}px;
      border-radius: 50%;
      background-color: {handle_grip_color};
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 2px 6px rgba(0,0,0,0.2);
      pointer-events: none;
      position: relative;
      font-family: system-ui, -apple-system, sans-serif;
      font-weight: bold;
      color: {handle_arrow_color};
      font-size: {handle_grip_size * 0.4}px;
      line-height: 1;
    }}
    .dj-image-slider-handle-grip::before {{
      content: '<>';
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
    }}
    .dj-image-slider-handle-grip::after {{
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      width: {handle_grip_size * 0.8}px;
      height: {handle_grip_size * 0.8}px;
      border-radius: 50%;
      border: 2px solid {handle_arrow_color};
      background-color: {handle_grip_color};
    }}
    .dj-image-slider-label {{
      position: absolute;
      {if (label_position == 'top') 'top: 10px;' else 'bottom: 10px;'}
      padding: {label_padding};
      border-radius: 4px;
      font-family: {label_font_family};
      font-size: {label_font_size};
      color: {label_text_color};
      background-color: {label_background_color};
      z-index: 2;
      pointer-events: none;
      transition: opacity 0.3s ease;
    }}
    .dj-image-slider-label.dj-image-slider-label-left {{ left: 10px; }}
    .dj-image-slider-label.dj-image-slider-label-right {{ right: 10px; }}
    .dj-image-slider-label-top {{ top: 10px; bottom: auto !important; }}
    .dj-image-slider-label-bottom {{ bottom: 10px; top: auto !important; }}
    .dj-image-slider-label-hidden {{
      opacity: 0;
    }}
    .dj-image-slider-container:hover .dj-image-slider-label-hidden {{
      opacity: 1;
    }}
  "
  )

  # --- JavaScript for Slider Functionality ---
  script_html <- glue::glue(
    "
    <script id='{script_tag_id}'>
    (function() {{
      if (typeof window.djImageSlidersInitialized === 'undefined') {{
        window.djImageSlidersInitialized = new Set();
      }}

      function initDjImageSlider(sliderId) {{
        if (window.djImageSlidersInitialized.has(sliderId)) {{
          return;
        }}

        const slider = document.getElementById(sliderId);
        if (!slider) {{
          console.warn('DJ Image slider not found: ' + sliderId);
          return;
        }}

        const leftWrapper = slider.querySelector('.dj-image-slider-left-wrapper');
        const rightImg = slider.querySelector('.dj-image-slider-right-img');
        const handle = slider.querySelector('.dj-image-slider-handle');
        const config = JSON.parse(slider.dataset.config || '{{}}');

        // Set container height based on image height
        function updateContainerHeight() {{
          if (rightImg.complete) {{
            const height = rightImg.offsetHeight;
            slider.style.height = height + 'px';
            leftWrapper.style.height = height + 'px';
          }}
        }}

        // Update height when image loads
        rightImg.addEventListener('load', updateContainerHeight);
        // Also try immediately in case image is already loaded
        updateContainerHeight();

        let isDragging = false;
        let isActiveHover = false;

        function updateSliderPosition(clientX) {{
          const rect = slider.getBoundingClientRect();
          let x = clientX - rect.left;
          let percentage = (x / rect.width) * 100;
          percentage = Math.max(0, Math.min(100, percentage));

          leftWrapper.style.clipPath = `inset(0 ${{100 - percentage}}% 0 0)`;
          handle.style.left = percentage + '%';
        }}

        updateSliderPosition(slider.getBoundingClientRect().left + (slider.getBoundingClientRect().width * config.initialPos / 100));

        function startInteraction(event) {{
          if (!config.enableDrag) return;
          isDragging = true;
          slider.style.cursor = 'ew-resize';
          const clientX = event.touches ? event.touches[0].clientX : event.clientX;
          updateSliderPosition(clientX);
          if (event.preventDefault && event.type === 'touchstart') {{
             event.preventDefault();
          }}
        }}

        slider.addEventListener('mousedown', startInteraction);
        slider.addEventListener('touchstart', startInteraction, {{ passive: false }});

        function moveInteraction(event) {{
          const clientX = event.touches ? event.touches[0].clientX : event.clientX;
          if (isDragging && config.enableDrag) {{
            updateSliderPosition(clientX);
          }} else if (isActiveHover && config.slideOnHover && !isDragging && event.type === 'mousemove') {{
            updateSliderPosition(clientX);
          }}
        }}
        document.addEventListener('mousemove', moveInteraction);
        document.addEventListener('touchmove', moveInteraction, {{ passive: false }});

        function endInteraction() {{
          if (isDragging) {{
            isDragging = false;
            slider.style.cursor = 'default';
          }}
        }}
        document.addEventListener('mouseup', endInteraction);
        document.addEventListener('touchend', endInteraction);

        if (config.slideOnHover) {{
          slider.addEventListener('mouseenter', function() {{
            isActiveHover = true;
          }});
          slider.addEventListener('mouseleave', function() {{
            isActiveHover = false;
          }});
          slider.addEventListener('mousemove', function(event) {{
            if (!isDragging && isActiveHover) {{
              updateSliderPosition(event.clientX);
            }}
          }});
        }}
        window.djImageSlidersInitialized.add(sliderId);
      }}

      if (typeof window.initializeAllDjImageSliders !== 'function') {{
        window.initializeAllDjImageSliders = function() {{
          const sliders = document.querySelectorAll('.dj-image-slider-container');
          sliders.forEach(slider => {{
            if (slider.id && slider.dataset.config) {{
              initDjImageSlider(slider.id);
            }}
          }});
        }};
      }}

      if (document.readyState === 'loading') {{
        document.addEventListener('DOMContentLoaded', window.initializeAllDjImageSliders);
      }} else {{
        window.initializeAllDjImageSliders();
      }}
    }})();
    </script>
  "
  )

  # --- Configuration for JavaScript ---
  js_config <- jsonlite::toJSON(
    list(
      initialPos = initial_slider_position_percent,
      slideOnHover = slide_on_hover,
      enableDrag = enable_drag
    ),
    auto_unbox = TRUE
  )

  # --- Main HTML Output ---
  label_class <- if (show_labels_on_hover) {
    "dj-image-slider-label dj-image-slider-label-hidden"
  } else {
    "dj-image-slider-label"
  }
  label_class <- paste(
    label_class,
    paste0("dj-image-slider-label-", label_position)
  )

  label_left_html <- ""
  if (!is.null(label_left) && nzchar(trimws(label_left))) {
    label_left_html <- glue::glue(
      '<div class="{label_class} dj-image-slider-label-left" style="font-family: {label_font_family}; font-size: {label_font_size}; color: {label_text_color}; background-color: {label_background_color}; padding: {label_padding};">{htmltools::htmlEscape(label_left)}</div>'
    )
  }

  label_right_html <- ""
  if (!is.null(label_right) && nzchar(trimws(label_right))) {
    label_right_html <- glue::glue(
      '<div class="{label_class} dj-image-slider-label-right" style="font-family: {label_font_family}; font-size: {label_font_size}; color: {label_text_color}; background-color: {label_background_color}; padding: {label_padding};">{htmltools::htmlEscape(label_right)}</div>'
    )
  }

  html_output <- glue::glue(
    '
    <style>
      {css_styles}
    </style>
    <div id="{slider_id}"
         class="dj-image-slider-container"
         role="slider"
         aria-valuemin="0"
         aria-valuemax="100"
         aria-valuenow="{initial_slider_position_percent}"
         aria-label="{htmltools::htmlEscape(slider_aria_label)}"
         data-config=\'{js_config}\'>

      <div class="dj-image-slider-img-wrapper dj-image-slider-right-wrapper">
        <img src="{htmltools::htmlEscape(image_right_url)}"
             alt="{htmltools::htmlEscape(alt_right_image)}"
             class="dj-image-slider-img dj-image-slider-right-img"
             loading="lazy"
             draggable="false" />
        {label_right_html}
      </div>

      <div class="dj-image-slider-img-wrapper dj-image-slider-left-wrapper" style="clip-path: inset(0 {100 - initial_slider_position_percent}% 0 0);">
        <img src="{htmltools::htmlEscape(image_left_url)}"
             alt="{htmltools::htmlEscape(alt_left_image)}"
             class="dj-image-slider-img dj-image-slider-left-img"
             loading="lazy"
             draggable="false" />
        {label_left_html}
      </div>

      <div class="dj-image-slider-handle" style="left: {initial_slider_position_percent}%;">
        <div class="dj-image-slider-handle-grip"></div>
      </div>
    </div>
    {script_html}
  '
  )

  return(htmltools::HTML(html_output))
}
