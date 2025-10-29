#' Create a Self-Contained HTML Image Swiper
#'
#' This function generates the HTML, CSS, and JavaScript for a responsive
#' image slider. It allows for a dynamic number of images, navigation controls,
#' and an optional fixed overlay.
#'
#' @param image_data A list of lists. Each inner list must contain a `path`
#'   (a string for the image source URL) and can optionally contain a `caption`
#'   (a string to be displayed over the image).
#' @param overlay_path An optional string specifying the path to an overlay image.
#' @param gradient_color An optional string specifying the color for the edge gradient.
#'   Defaults to "#c1d9d9" (light blue-green). Set to NULL to disable the gradient.
#' @param gradient_stops An optional numeric vector of length 3 specifying the
#'   gradient stops: `c(left_opaque_end, middle_transparent, right_opaque_start)`.
#'   For example, `c(10, 50, 90)` will keep the gradient solid until 10%,
#'   fade to transparent at 50%, and then fade back to solid at 90%.
#'   Defaults to `NULL`, which uses `c(15, 50, 85)`.
#' @param aspect_ratio A string defining the aspect ratio for the slider items,
#'   e.g., "1/1" for a square or "16/9" for widescreen. Defaults to "1/1".
#' @param max_width An optional numeric value for the maximum width of the
#'   container in pixels. Defaults to `NULL`, allowing the slider to fill its
#'   parent's width.
#' @param debounce_delay An optional integer. The debounce delay in milliseconds
#' for the scroll event. Defaults to 0 (no delay). Set to a positive value (e.g., 50)
#' to delay the dot indicator update until scrolling has paused.
#' @param animation_duration An optional numeric value. The duration of the dot
#'   indicator's grow/shrink animation in seconds. Defaults to 0.3.
#'
#' @return An `htmltools::tagList` object that can be rendered directly in
#'   R Markdown, Shiny, or other HTML-supporting R environments.
#'
#' @importFrom htmltools tagList tags HTML htmlEscape
#'
#' @examples
#' # Define a list of images and their captions
#' image_list <- list(
#'   list(path = "http://b.staticfiles.at/elm/static/2025-dateien/first.webp", caption = "15. Oktober 2023"),
#'   list(path = "http://b.staticfiles.at/elm/static/2025-dateien/middle.webp"),
#'   list(path = "http://b.staticfiles.at/elm/static/2025-dateien/last.webp", caption = "11. Mai 2025")
#' )
#'
#' # Create the swiper (will be an HTML object)
#' swiper_widget <- html_create_image_swiper(
#'   image_data = image_list,
#'   overlay_path = "http://b.staticfiles.at/elm/static/2025-dateien/slider_overview_final.png",
#'   gradient_color = "#c1d9d9",  # Optional: customize gradient color or set to NULL to disable
#'   max_width = 615 # Optional: Set a max-width for the container
#' )
#'
#' @export
html_create_image_swiper <- function(
  image_data,
  overlay_path = NULL,
  gradient_color = "#c1d9d9",
  gradient_stops = NULL,
  aspect_ratio = "1/1",
  max_width = NULL,
  debounce_delay = 0,
  animation_duration = 0.3
) {
  # Validate input
  if (!is.list(image_data) || length(image_data) == 0) {
    stop('`image_data` must be a non-empty list of lists with a `path`.')
  }
  for (item in image_data) {
    if (!is.list(item) || is.null(item$path)) {
      stop('Each entry in `image_data` must be a list with a `path`.')
    }
  }

  # Generate the HTML for each slider item
  slider_items <- lapply(image_data, function(item) {
    caption_tag <- NULL
    if (!is.null(item$caption)) {
      caption_tag <- tags$span(
        class = "dj-caption",
        htmltools::htmlEscape(item$caption)
      )
    }
    tags$div(
      class = "basic-slider-item",
      caption_tag,
      tags$img(
        src = item$path,
        alt = htmltools::htmlEscape(item$caption %||% "Slider Image")
      )
    )
  })

  # Define the optional overlay image
  overlay_tag <- NULL
  if (!is.null(overlay_path)) {
    overlay_tag <- tags$img(
      class = "slider-overview",
      src = overlay_path,
      alt = "Map Overlay"
    )
  }

  # Generate gradient CSS based on the gradient_color parameter
  gradient_css <- ""
  if (!is.null(gradient_color)) {
    if (is.null(gradient_stops)) {
      # Default stops for a gradient that is opaque at the edges
      gradient_stops <- c(15, 50, 85)
    } else {
      if (!is.numeric(gradient_stops) || length(gradient_stops) != 3) {
        stop(
          "`gradient_stops` must be a numeric vector of length 3, e.g., c(15, 50, 85)."
        )
      }
    }
    gradient_css <- sprintf(
      ".gradient { position: absolute; width: 100%%; height: 100%%; background-image: linear-gradient(to right, %s 0%%, %s %d%%, transparent %d%%, %s %d%%, %s 100%%); z-index: 10; pointer-events: none; top: 0; left: 0; }",
      gradient_color,
      gradient_color,
      gradient_stops[1],
      gradient_stops[2],
      gradient_color,
      gradient_stops[3],
      gradient_color
    )
  }

  # Conditionally generate max-width CSS
  max_width_css <- ""
  if (!is.null(max_width)) {
    max_width_css <- sprintf("max-width: %spx;", max_width)
  }

  # SVG for navigation buttons as raw HTML
  prev_svg <- HTML(
    '<svg viewBox="0 0 1200 1200" xmlns="http://www.w3.org/2000/svg"><path d="m825.84 1176c-29.668 0.035156-58.195-11.453-79.559-32.039l-432.84-417.6c-22.719-21.879-39.117-49.48-47.469-79.895-8.3555-30.414-8.3555-62.516 0-92.93 8.3516-30.414 24.75-58.016 47.469-79.895l432.84-417.6c29.453-28.402 71.82-38.934 111.14-27.629 39.324 11.305 69.629 42.734 79.5 82.441 9.8711 39.707-2.1914 81.664-31.645 110.07l-393 379.08 393 379.08c22.039 21.238 34.66 50.418 35.039 81.027 0.37891 30.605-11.516 60.09-33.027 81.867-21.508 21.773-50.844 34.031-81.453 34.027z"/></svg>'
  )
  next_svg <- prev_svg

  # Define the complete HTML structure using htmltools
  swiper_component <- tagList(
    tags$style(HTML(paste0(
      sprintf(
        "
      .basic-slider-container { position: relative; width: 100%%; %s margin: 0 auto; font-family: STMatilda Info Variable, system-ui, sans-serif; }
      .image-wrapper { position: relative; width: 100%%; overflow: hidden; }
      .basic-slider-scroll { display: flex; gap: 10px; overflow-x: auto; scroll-snap-type: x mandatory; position: relative; width: 100%%; -ms-overflow-style: none; scrollbar-width: none; padding: 0 10%%; box-sizing: border-box; }
      .basic-slider-scroll::-webkit-scrollbar { display: none; }
      .basic-slider-item { flex-shrink: 0; scroll-snap-align: center; width: 100%%; position: relative; aspect-ratio: %s; }
      .basic-slider-item img { display: block; width: 100%%; height: 100%%; border-radius: 5px; object-fit: cover; }
      .dj-caption { position: absolute; top: 5px; left: 5px; z-index: 20; background: rgba(0, 0, 0, 0.6); color: white; padding: 4px 8px; border-radius: 4px; font-size: 20px; font-weight: 400; }
      ",
        max_width_css,
        aspect_ratio
      ),
      gradient_css,
      sprintf(
        "
      .slider-overview { position: absolute; bottom: 0; right: 0; height: 46%%; z-index: 30; max-width: 100%%; }
      .nav-button { position: absolute; top: 40%%; transform: translateY(-50%%); background: rgba(0, 0, 0, 0.5); color: white; border: none; width: 3.125rem; height: 3.125rem; border-radius: 50%%; cursor: pointer; z-index: 20; display: flex; align-items: center; justify-content: center; padding: 0; }
      .nav-button svg { width: 1.5rem; height: 1.5rem; fill: currentColor; }
      @media (max-width: 600px) { .nav-button { width: 2.5rem; height: 2.5rem; } .nav-button svg { width: 1.25rem; height: 1.25rem; } }
      .nav-button.next svg { transform: scaleX(-1); }
      .nav-button:disabled { opacity: 0.3; cursor: not-allowed; }
      .nav-button.prev { left: 0.625rem; }
      .nav-button.next { right: 0.625rem; }
      .dots { display: flex; justify-content: center; gap: 0.5rem; margin-top: 0.625rem; }
      .dot { width: 0.625rem; height: 0.625rem; border-radius: 50%%; background: #efefef; cursor: pointer; transition: all %.2fs ease; }
      .dot.active { background: #454545; transform: scale(1.5); }
    ",
        animation_duration
      )
    ))),
    tags$div(
      class = "basic-slider-container",
      tags$div(
        class = "image-wrapper",
        if (!is.null(gradient_color)) tags$div(class = "gradient"),
        tags$div(class = "basic-slider-scroll", slider_items),
        overlay_tag,
        tags$button(class = "nav-button prev", prev_svg),
        tags$button(class = "nav-button next", next_svg)
      ),
      tags$div(class = "dots")
    ),
    tags$script(HTML(sprintf(
      "
      (function() {
        const debounceDelay = %d;
        const allSliders = document.querySelectorAll('.basic-slider-container:not([data-initialized])');
        const container = allSliders[allSliders.length - 1];
        if (!container) return;
        container.setAttribute('data-initialized', 'true');
        const slider = container.querySelector('.basic-slider-scroll');
        const slides = container.querySelectorAll('.basic-slider-item');
        const prevBtn = container.querySelector('.prev');
        const nextBtn = container.querySelector('.next');
        const dotsContainer = container.querySelector('.dots');
        if (!slider || !slides || slides.length === 0) return;
        let current_image = 0;
        const total_images = slides.length;
        for (let i = 0; i < total_images; i++) {
          const dot = document.createElement('div');
          dot.className = 'dot' + (i === 0 ? ' active' : '');
          dot.onclick = () => goToSlide(i);
          dotsContainer.appendChild(dot);
        }
        function updateButtons() {
          prevBtn.disabled = current_image === 0;
          nextBtn.disabled = current_image >= total_images - 1;
        }
        function updateDots() {
          const dots = dotsContainer.querySelectorAll('.dot');
          dots.forEach((dot, i) => {
            dot.className = 'dot' + (i === current_image ? ' active' : '');
          });
        }
        function updateCurrentImageOnScroll() {
          const containerRect = slider.getBoundingClientRect();
          let maxVisibleIndex = current_image;
          let maxVisibleArea = 0;
          slides.forEach((slide, index) => {
            const rect = slide.getBoundingClientRect();
            const visibleLeft = Math.max(rect.left, containerRect.left);
            const visibleRight = Math.min(rect.right, containerRect.right);
            const visibleWidth = Math.max(0, visibleRight - visibleLeft);
            if (visibleWidth > maxVisibleArea) {
              maxVisibleArea = visibleWidth;
              maxVisibleIndex = index;
            }
          });
          if (current_image !== maxVisibleIndex) {
            current_image = maxVisibleIndex;
            updateButtons();
            updateDots();
          }
        }
        function goToSlide(index) {
          const slideWidth = slides[0].clientWidth;
          const gap = parseInt(window.getComputedStyle(slider).gap) || 10;
          slider.scrollTo({ left: index * (slideWidth + gap), behavior: 'smooth' });
          current_image = index;
          updateButtons();
          updateDots();
        }
        prevBtn.onclick = () => { if (current_image > 0) goToSlide(current_image - 1); };
        nextBtn.onclick = () => { if (current_image < total_images - 1) goToSlide(current_image + 1); };
        if (debounceDelay > 0) {
          let scrollTimeout;
          slider.addEventListener('scroll', () => {
            clearTimeout(scrollTimeout);
            scrollTimeout = setTimeout(updateCurrentImageOnScroll, debounceDelay);
          });
        } else {
          slider.addEventListener('scroll', updateCurrentImageOnScroll);
        }
        let resizeTimeout;
        window.addEventListener('resize', () => {
          clearTimeout(resizeTimeout);
          resizeTimeout = setTimeout(updateCurrentImageOnScroll, 50);
        });
        updateButtons();
        updateDots();
      })();
    ",
      debounce_delay
    )))
  )

  return(swiper_component)
}

# Helper for providing a default value in case of NULL
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}
