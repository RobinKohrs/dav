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
#'   Defaults to "hsla(180, 23%, 81%, 1)" (light blue-green). Set to NULL to disable the gradient.
#' @param gradient_stops An optional named character vector where names are
#'   percentage stops (e.g., `'0'`, `'50'`) and values are CSS colors (e.g.,
#'   `'#ffffff'`, `'transparent'`). This allows for creating complex, multi-color
#'   gradients. If `NULL` (the default), a standard gradient is created using
#'   `gradient_color`.
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
#' @param object_fit A string specifying how an image should be resized to fit
#'   its container. Common values are "cover", "contain", "fill", "none",
#'   or "scale-down". Defaults to "contain".
#' @param main_image_width An optional numeric value (1-100) for the percentage
#'   width of the central image. Defaults to 60.
#' @param output_file An optional string. If provided, the generated HTML will
#'   be saved to this file path. Defaults to `NULL`.
#' @param overwrite A logical value. If `TRUE` (the default), an existing output
#'   file will be overwritten. If `FALSE`, the function will stop with an error
#'   if the file already exists.
#' @param dot_size A string specifying the CSS size for the navigation dots
#'   (e.g., "1rem", "10px", "4pt"). Defaults to "0.625rem".
#' @param include_html_header A logical value. If `TRUE`, the output file will
#'   be a complete HTML document, including the necessary viewport meta tag for
#'   proper mobile scaling. Defaults to `FALSE`, which outputs only the HTML
#'   fragment.
#' @param title An optional string. A header title to display above the slider.
#' @param subtitle An optional string. A subtitle to display below the title.
#' @param caption_position A string, either "inside" (default) or "outside".
#'   If "inside", captions are overlayed on the image. If "outside", they are
#'   placed above or below the image as standard text.
#' @param outside_caption_position A string, either "bottom" (default) or "top".
#'   Only applies if `caption_position` is "outside".
#' @param dots_position A string, either "bottom" (default) or "top".
#'   Controls where the navigation dots are placed relative to the slider.
#'
#' @return An `htmltools::tagList` object that can be rendered directly in
#'   R Markdown, Shiny, or other HTML-supporting R environments.
#'
#' @importFrom htmltools tagList tags HTML htmlEscape
#' @importFrom cli cli_alert_success cli_abort
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
#'   gradient_color = "hsla(180, 23%, 81%, 1)",
#'   max_width = 615, # Optional: Set a max-width for the container
#'   caption_position = "outside",
#'   dots_position = "top"
#' )
#'
#' @export
html_create_image_swiper <- function(
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
  dots_position = c("bottom", "top")
) {
  # Validate input
  caption_position <- match.arg(caption_position)
  outside_caption_position <- match.arg(outside_caption_position)
  dots_position <- match.arg(dots_position)

  if (!is.list(image_data) || length(image_data) == 0) {
    stop('`image_data` must be a non-empty list of lists with a `path`.')
  }
  for (item in image_data) {
    if (!is.list(item) || is.null(item$path)) {
      stop('Each entry in `image_data` must be a list with a `path`.')
    }
  }

  if (
    !is.numeric(main_image_width) ||
      main_image_width < 1 ||
      main_image_width > 100
  ) {
    stop("`main_image_width` must be a numeric value between 1 and 100.")
  }
  side_peek_width <- (100 - main_image_width) / 2

  uid <- paste0(
    "swiper-",
    paste(sample(c(letters, 0:9), 8, replace = TRUE), collapse = "")
  )

  # Generate the HTML for each slider item
  slider_items <- list()
  caption_items <- list()

  for (i in seq_along(image_data)) {
    item <- image_data[[i]]

    # 1. Build Image Item (always)
    # If caption is INSIDE, we include it here.
    inside_caption_tag <- NULL
    if (!is.null(item$caption) && caption_position == "inside") {
      inside_caption_tag <- tags$div(
        class = "dj-caption",
        htmltools::htmlEscape(item$caption)
      )
    }

    img_tag <- tags$div(
      class = "basic-slider-item",
      tags$div(
        class = "img-container",
        inside_caption_tag,
        tags$img(
          src = item$path,
          alt = htmltools::htmlEscape(item$caption %||% "Slider Image")
        )
      )
    )
    slider_items[[i]] <- img_tag

    # 2. Build Caption Item (if OUTSIDE)
    if (caption_position == "outside") {
      # HTML allowed for outside
      cap_content <- if (!is.null(item$caption)) {
        htmltools::HTML(item$caption)
      } else {
        ""
      }
      cap_tag <- tags$div(
        class = "caption-item",
        cap_content
      )
      caption_items[[i]] <- cap_tag
    }
  }

  # Wrapper for captions
  # We render captions in a scroll container that mirrors the image scroller geometry
  # so both can be synced via scrollLeft (same speed, same snap behavior).
  caption_container <- if (caption_position == "outside") {
    tags$div(
      class = "caption-container",
      tags$div(class = "caption-scroll", caption_items)
    )
  } else {
    NULL
  }

  # Define the optional overlay image
  overlay_tag <- NULL
  if (!is.null(overlay_path)) {
    overlay_tag <- tags$img(
      class = "slider-overview",
      src = overlay_path,
      alt = "Map Overlay"
    )
  }

  # Generate gradient CSS
  gradient_css <- ""
  # Create a gradient if a color or stops are provided
  if (!is.null(gradient_color) || !is.null(gradient_stops)) {
    colors <- NULL
    stops <- NULL
    # If gradient_stops is not provided, create a default one using gradient_color
    if (is.null(gradient_stops)) {
      # Default behavior: Sharp transition at 10% and 90%
      stops <- c(0, 10, 10, 90, 90, 100)
      colors <- c(
        gradient_color,
        gradient_color,
        "transparent",
        "transparent",
        gradient_color,
        gradient_color
      )
    } else {
      # Validate the user-provided named vector
      if (
        !is.vector(gradient_stops) ||
          is.null(names(gradient_stops)) ||
          !is.character(gradient_stops)
      ) {
        stop(
          "`gradient_stops` must be a named character vector, where names are percentages."
        )
      }
      stops_num <- suppressWarnings(as.numeric(names(gradient_stops)))
      if (anyNA(stops_num)) {
        stop("Names of `gradient_stops` must be numeric percentages.")
      }
      colors <- as.character(gradient_stops)
      stops <- stops_num
    }

    # Construct the gradient string from the list
    gradient_parts <- mapply(
      function(color, percent) {
        sprintf("%s %s%%", color, percent)
      },
      colors,
      stops,
      SIMPLIFY = FALSE
    )

    gradient_values <- paste(unlist(gradient_parts), collapse = ", ")

    # Standard full coverage since wrapper now only contains images
    grad_style <- "position: absolute; width: 100%; height: 100%; top: 0; left: 0;"

    gradient_css <- sprintf(
      ".%s .gradient { %s background-image: linear-gradient(to right, %s); z-index: 10; pointer-events: none; }",
      uid,
      grad_style,
      gradient_values
    )
  }

  # Conditionally generate max-width CSS
  max_width_css <- ""
  if (!is.null(max_width)) {
    max_width_css <- sprintf("max-width: %spx;", max_width)
  }

  # Determine CSS for caption based on position
  caption_css <- if (caption_position == "inside") {
    "position: absolute; top: 5px; left: 5px; z-index: 20; background: rgba(0, 0, 0, 0.6); color: white; padding: 4px 8px; border-radius: 4px; font-size: 20px; font-weight: 400;"
  } else {
    # Outside caption CSS - now handled by container/item classes mostly, but this applies to text styling
    "font-size: 1rem; line-height: 1.4; text-align: left; color: inherit;"
  }

  # Dots margin adjustment based on position
  dots_margin <- if (dots_position == "bottom") {
    "margin-top: 0.625rem;"
  } else {
    "margin-bottom: 0.625rem;"
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
      .%s.basic-slider-container { position: relative; width: 100%%; %s margin: 0 auto; font-family: STMatilda Info Variable, system-ui, sans-serif; }
      .%s .slider-header { margin-bottom: 1rem; text-align: left; }
      .%s .slider-title { font-size: 1.25rem; font-weight: bold; margin: 0 0 0.25rem 0; }
      .%s .slider-subtitle { font-size: 1rem; color: #666; margin: 0; }
      .%s .image-wrapper { position: relative; width: 100%%; overflow: hidden; }
      .%s .basic-slider-scroll { display: flex; gap: 10px; overflow-x: auto; scroll-snap-type: x mandatory; position: relative; width: 100%%; -ms-overflow-style: none; scrollbar-width: none; }
      .%s .basic-slider-scroll::before, .%s .basic-slider-scroll::after { content: ''; flex-basis: %.2f%%; flex-shrink: 0; }
      .%s .basic-slider-scroll::-webkit-scrollbar { display: none; }
      .%s .basic-slider-item { flex-shrink: 0; scroll-snap-align: center; width: %.2f%%; position: relative; }
      .%s .img-container { position: relative; width: 100%%; aspect-ratio: %s; }
      .%s .img-container img { display: block; width: 100%%; height: 100%%; border-radius: 5px; object-fit: %s; }
      .%s .dj-caption { %s }
      .%s .caption-container { position: relative; width: 100%%; margin: 0.5rem 0; box-sizing: border-box; }
      /* Caption strip: must be scrollable for programmatic scrollLeft, but should not capture user swipes. */
      .%s .caption-scroll { display: flex; align-items: flex-start; gap: 0; overflow-x: auto; overflow-y: visible; position: relative; width: 100%%; -ms-overflow-style: none; scrollbar-width: none; pointer-events: none; }
      .%s .caption-scroll::-webkit-scrollbar { display: none; }
      /* Avoid per-item horizontal padding; it makes each slide look shifted vs the container. */
      .%s .caption-item { flex: 0 0 100%%; width: 100%%; position: relative; padding: 0; box-sizing: border-box; }
      ",
        uid,
        max_width_css,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        side_peek_width,
        uid,
        uid,
        main_image_width,
        uid,
        aspect_ratio,
        uid,
        object_fit,
        uid,
        caption_css,
        uid,
        uid,
        uid,
        uid
      ),
      gradient_css,
      sprintf(
        "
      .%s .slider-overview { position: absolute; bottom: 0; right: 0; height: 46%%; z-index: 30; max-width: 100%%; }
      .%s .nav-button { position: absolute; top: 40%%; transform: translateY(-50%%); background: rgba(100,100,100); color: white; border: none; width: 3.125rem; height: 3.125rem; border-radius: 50%%; cursor: pointer; z-index: 20; display: flex; align-items: center; justify-content: center; padding: 0; }
      .%s .nav-button svg { width: 1.5rem; height: 1.5rem; fill: currentColor; }
      @media (max-width: 600px) { .%s .nav-button { width: 2.5rem; height: 2.5rem; } .%s .nav-button svg { width: 1.25rem; height: 1.25rem; } }
      .%s .nav-button.next svg { transform: scaleX(-1); }
      .%s .nav-button:disabled { opacity: 0.3; cursor: not-allowed; }
      .%s .nav-button.prev { left: 0.625rem; }
      .%s .nav-button.next { right: 0.625rem; }
      .%s .dots { display: flex; justify-content: center; gap: 0.5rem; %s }
      .%s .dot { width: %s; height: %s; border-radius: 50%%; background: #efefef; cursor: pointer; transition: all %.2fs ease; }
      .%s .dot.active { background: #454545; transform: scale(1.5); }
    ",
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        uid,
        dots_margin,
        uid,
        dot_size,
        dot_size,
        animation_duration,
        uid
      )
    ))),
    tags$div(
      class = paste("basic-slider-container", uid),
      # Header
      if (!is.null(title) || !is.null(subtitle)) {
        tags$div(
          class = "slider-header",
          if (!is.null(title)) tags$div(class = "slider-title", title),
          if (!is.null(subtitle)) tags$div(class = "slider-subtitle", subtitle)
        )
      },
      # Dots (Top)
      if (dots_position == "top") tags$div(class = "dots"),

      # Captions (Top)
      if (caption_position == "outside" && outside_caption_position == "top") {
        caption_container
      },

      # Slider
      tags$div(
        class = "image-wrapper",
        if (!is.null(gradient_color) || !is.null(gradient_stops)) {
          tags$div(class = "gradient")
        },
        tags$div(class = "basic-slider-scroll", slider_items),
        overlay_tag,
        tags$button(class = "nav-button prev", prev_svg),
        tags$button(class = "nav-button next", next_svg)
      ),

      # Captions (Bottom)
      if (
        caption_position == "outside" && outside_caption_position == "bottom"
      ) {
        caption_container
      },

      # Dots (Bottom)
      if (dots_position == "bottom") tags$div(class = "dots")
    ),
    tags$script(HTML(sprintf(
      "
      (function() {
        const debounceDelay = %d;
        const container = document.querySelector('.%s.basic-slider-container:not([data-initialized])');
        if (!container) return;
        container.setAttribute('data-initialized', 'true');
        const slider = container.querySelector('.basic-slider-scroll');
        const slides = container.querySelectorAll('.basic-slider-item');
        const prevBtn = container.querySelector('.prev');
        const nextBtn = container.querySelector('.next');
        const dotsContainer = container.querySelector('.dots');
        const captionContainer = container.querySelector('.caption-container');
        const captionScroll = container.querySelector('.caption-scroll');
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
        // One-way sync: captions follow images.
        // Note: the image scroller has side spacers, so scrollLeft at slide 0 is not necessarily 0.
        // We capture a baseline offset so captions can start at scrollLeft=0 (no visual left shift).
        let captionSyncRaf = null;
        let imageScrollBase = null;
        function syncCaptionsToImages() {
          if (!captionScroll) return;
          if (captionSyncRaf) cancelAnimationFrame(captionSyncRaf);
          captionSyncRaf = requestAnimationFrame(() => {
            // Smooth mapping: map image scroll position in slides to caption pages.
            // This avoids jumpiness from before/after spacers and scrollWidth rounding.
            const slideWidth = slides[0].clientWidth;
            const gap = parseInt(window.getComputedStyle(slider).gap) || 10;
            const step = slideWidth + gap;
            if (step <= 0) return;
            if (imageScrollBase === null) imageScrollBase = slider.scrollLeft;
            const posInSlides = (slider.scrollLeft - imageScrollBase) / step; // e.g. 0.0 .. (n-1)
            const target = posInSlides * captionScroll.clientWidth;
            const capMax = captionScroll.scrollWidth - captionScroll.clientWidth;
            captionScroll.scrollLeft = Math.max(0, Math.min(capMax, target));
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
            // Hard-align captions to the page once we know the active slide.
            // This avoids tiny drift from subpixel rounding during snap.
            if (captionScroll) captionScroll.scrollLeft = current_image * captionScroll.clientWidth;
          }
        }
        function goToSlide(index) {
          const slideWidth = slides[0].clientWidth;
          const gap = parseInt(window.getComputedStyle(slider).gap) || 10;
          const step = slideWidth + gap;
          if (imageScrollBase === null) imageScrollBase = slider.scrollLeft;
          const left = imageScrollBase + index * step;
          slider.scrollTo({ left, behavior: 'smooth' });
          if (captionScroll) {
            const capLeft = index * captionScroll.clientWidth;
            captionScroll.scrollTo({ left: capLeft, behavior: 'smooth' });
          }
          current_image = index;
          updateButtons();
          updateDots();
        }
        prevBtn.onclick = () => { if (current_image > 0) goToSlide(current_image - 1); };
        nextBtn.onclick = () => { if (current_image < total_images - 1) goToSlide(current_image + 1); };
        // Keep captions in perfect sync with the image scroller while swiping
        if (captionScroll) {
          slider.addEventListener('scroll', syncCaptionsToImages, { passive: true });
        }

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
        // Initial sync (important when rendered mid-scroll)
        // Establish baseline after layout so slide 0 maps to caption scrollLeft=0.
        requestAnimationFrame(() => {
          imageScrollBase = slider.scrollLeft;
          if (captionScroll) captionScroll.scrollLeft = 0;
        });
      })();
    ",
      debounce_delay,
      uid
    )))
  )

  # If an output file is specified, save the HTML
  if (!is.null(output_file)) {
    # Check if the file exists and should not be overwritten
    if (file.exists(output_file) && !overwrite) {
      cli::cli_abort(
        "File already exists at '{.path {output_file}}' and `overwrite` is `FALSE`."
      )
    }
    # Ensure the directory exists
    dir.create(dirname(output_file), showWarnings = FALSE, recursive = TRUE)
    # Render the component to a character string
    html_content <- as.character(swiper_component)

    # If requested, wrap the fragment in a full HTML document
    if (include_html_header) {
      html_content <- paste(
        "<!DOCTYPE html>",
        "<html lang=\"en\">",
        "<head>",
        "  <meta charset=\"UTF-8\" />",
        "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />",
        "  <title>Swiper</title>",
        "</head>",
        "<body>",
        html_content,
        "</body>",
        "</html>",
        sep = "\n"
      )
    }

    writeLines(html_content, con = output_file)
    cli::cli_alert_success(
      "Swiper HTML successfully written to '{.path {output_file}}'"
    )
  }

  return(swiper_component)
}

# Helper for providing a default value in case of NULL
`%||%` <- function(a, b) {
  if (is.null(a)) b else a
}
