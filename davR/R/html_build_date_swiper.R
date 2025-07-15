#' Create an HTML Date Swiper
#'
#' Generates HTML, CSS, and JavaScript for a responsive date-based image swiper.
#' Each image is shown with its date in a styled overlay. Navigation buttons and dots are included.
#'
#' @param files A list of lists, each with `image_path` and `image_date` entries.
#' @return An HTML string (as htmltools::HTML) for embedding the swiper.
#' @importFrom htmltools htmlEscape HTML
#' @importFrom glue glue
#' @export
html_build_date_swiper = function(files) {
  if (!is.list(files) || length(files) == 0) {
    stop('`files` must be a non-empty list of lists with image_path and image_date.')
  }
  for (f in files) {
    if (!is.list(f) || is.null(f$image_path) || is.null(f$image_date)) {
      stop('Each entry in `files` must be a list with image_path and image_date.')
    }
  }

  # Build the HTML for each image
  items_html = vapply(files, function(f) {
    glue::glue(
      '<div class="basic-slider-item">\n<span class="dj-date">{htmltools::htmlEscape(f$image_date)}</span>\n<img src="{htmltools::htmlEscape(f$image_path)}" alt=""/>\n</div>'
    )
  }, character(1))

  # The static CSS and JS (copied from user example)
  css = '<style>
      .basic-slider-container { position: relative; width: 100%; max-width: 615px; font-family: STMatilda Info Variable, system-ui, sans-serif; }
      .image-wrapper { position: relative; width: 100%; overflow: hidden; }
      .basic-slider-scroll { display: flex; gap: 10px; overflow-x: auto; scroll-snap-type: x mandatory; position: relative; width: 100%; -ms-overflow-style: none; scrollbar-width: none; }
      .basic-slider-scroll::-webkit-scrollbar { display: none; }
      .basic-slider-item { flex-shrink: 0; scroll-snap-type: x mandatory; scroll-snap-align: center; max-width: 80%; height: 100%; position: relative; }
      .basic-slider-item img { display: block; width: 100%; height: 100%; border-radius: 5px; }
      .basic-slider-item:last-child { padding-right: 30px; }
      .dj-date { position: absolute; top: 5px; left: 5px; z-index: 20; background: rgba(0, 0, 0, 0.6); color: white; padding: 4px 8px; border-radius: 4px; font-size: 20px; font-weight: 400; }
      .gradient { position: absolute; width: 100%; height: 100%; background-image: linear-gradient(to right, #c1d9d9 0%, transparent 10%, transparent 83%, #c1d9d9 100%); z-index: 10; pointer-events: none; top: 0; left: 0; }
      .slider-overview { position: absolute; bottom: 0; right: 0; height: 46%; z-index: 30; max-width: 100%; }
      .nav-button { position: absolute; top: 40%; transform: translateY(-50%); background: rgba(0, 0, 0, 0.5); color: white; border: none; width: 50px; height: 50px; border-radius: 50%; cursor: pointer; z-index: 20; display: flex; align-items: center; justify-content: center; padding: 0; }
      .nav-button svg { width: 24px; height: 24px; fill: currentColor; }
      @media (max-width: 600px) { .nav-button { width: 40px; height: 40px; } .nav-button svg { width: 20px; height: 20px; } }
      .nav-button.next svg { transform: scaleX(-1); }
      .nav-button:disabled { opacity: 0.3; cursor: not-allowed; }
      .nav-button.prev { left: 10px; }
      .nav-button.next { right: 10px; }
      .dots { display: flex; justify-content: center; gap: 8px; margin-top: 10px; }
      .dot { width: 10px; height: 10px; border-radius: 50%; background: #efefef; cursor: pointer; transition: all 0.15s ease; }
      .dot.active { background: #454545; transform: scale(1.5); }
</style>'

  nav_buttons = '<button class="nav-button prev"><svg viewBox="0 0 1200 1200" xmlns="http://www.w3.org/2000/svg"><path d="m825.84 1176c-29.668 0.035156-58.195-11.453-79.559-32.039l-432.84-417.6c-22.719-21.879-39.117-49.48-47.469-79.895-8.3555-30.414-8.3555-62.516 0-92.93 8.3516-30.414 24.75-58.016 47.469-79.895l432.84-417.6c29.453-28.402 71.82-38.934 111.14-27.629 39.324 11.305 69.629 42.734 79.5 82.441 9.8711 39.707-2.1914 81.664-31.645 110.07l-393 379.08 393 379.08c22.039 21.238 34.66 50.418 35.039 81.027 0.37891 30.605-11.516 60.09-33.027 81.867-21.508 21.773-50.844 34.031-81.453 34.027z"/></svg></button>\n<button class="nav-button next"><svg viewBox="0 0 1200 1200" xmlns="http://www.w3.org/2000/svg"><path d="m825.84 1176c-29.668 0.035156-58.195-11.453-79.559-32.039l-432.84-417.6c-22.719-21.879-39.117-49.48-47.469-79.895-8.3555-30.414-8.3555-62.516 0-92.93 8.3516-30.414 24.75-58.016 47.469-79.895l432.84-417.6c29.453-28.402 71.82-38.934 111.14-27.629 39.324 11.305 69.629 42.734 79.5 82.441 9.8711 39.707-2.1914 81.664-31.645 110.07l-393 379.08 393 379.08c22.039 21.238 34.66 50.418 35.039 81.027 0.37891 30.605-11.516 60.09-33.027 81.867-21.508 21.773-50.844 34.031-81.453 34.027z"/></svg></button>'

  html = glue::glue('
{css}
<div class="basic-slider-container">
<div class="image-wrapper">
<div class="gradient"></div>
<div class="basic-slider-scroll">
{paste(items_html, collapse = "\n")}
</div>
{nav_buttons}
</div>
<div class="dots"></div>
</div>')

  js = '<script>
      (function() {
        const allSliders = document.querySelectorAll(".basic-slider-container:not([data-initialized])");
        const container = allSliders[allSliders.length - 1];
        if (!container) return;
        container.setAttribute("data-initialized", "true");
 
        const slider = container.querySelector(".basic-slider-scroll");
        const slides = container.querySelectorAll(".basic-slider-item");
        const prevBtn = container.querySelector(".prev");
        const nextBtn = container.querySelector(".next");
        const dotsContainer = container.querySelector(".dots");
 
        if (!slider || !slides || slides.length === 0) return;
 
        let current_image = 0;
        const total_images = slides.length;
 
        for (let i = 0; i < total_images; i++) {
          const dot = document.createElement("div");
          dot.className = "dot" + (i === 0 ? " active" : "");
          dot.onclick = () => goToSlide(i);
          dotsContainer.appendChild(dot);
        }
 
        function updateButtons() {
          prevBtn.disabled = current_image === 0;
          nextBtn.disabled = current_image >= total_images - 1;
        }
 
        function updateDots() {
          const dots = dotsContainer.querySelectorAll(".dot");
          dots.forEach((dot, i) => {
            dot.className = "dot" + (i === current_image ? " active" : "");
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
          slider.scrollTo({ left: index * (slideWidth + gap), behavior: "smooth" });
          current_image = index;
          updateButtons();
          updateDots();
        }
 
        prevBtn.onclick = () => { if (current_image > 0) goToSlide(current_image - 1); };
        nextBtn.onclick = () => { if (current_image < total_images - 1) goToSlide(current_image + 1); };
 
        let scrollTimeout;
        slider.addEventListener("scroll", () => {
          clearTimeout(scrollTimeout);
          scrollTimeout = setTimeout(updateCurrentImageOnScroll, 150);
        });
 
        window.addEventListener("resize", () => {
          clearTimeout(scrollTimeout);
          scrollTimeout = setTimeout(updateCurrentImageOnScroll, 150);
        });
 
        updateButtons();
        updateDots();
      })();
</script>'

  htmltools::HTML(paste0(html, js))
} 