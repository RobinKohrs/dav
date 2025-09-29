#' KJN Theme for ggplot2 with Markdown Support
#'
#' This theme provides a clean look for ggplot2 plots, using Roboto and black text,
#' and leverages `ggtext::element_markdown()` for enhanced text styling capabilities
#' in titles, subtitles, captions, axis titles, and legend text.
#' It builds upon `theme_minimal()`.
#'
#' This theme attempts to use the "Roboto" font family. For this to work
#' correctly, **"Roboto" should be installed as a system font**. If not found,
#' a message is displayed, and `ggplot2` may fall back to a default.
#' Users can also employ the `showtext` package for font management.
#'
#' **Using Markdown:**
#' When using this theme, you can use markdown/HTML in `labs()` for elements like
#' `title`, `subtitle`, `caption`, `x`, `y`, and `legend.title`.
#' Example: `labs(title = "My <b style='color:blue;'>Awesome</b> Title <small>(in 10px)</small>")`
#' Note: `element_markdown` primarily affects theme elements. For markdown in `labs`,
#' `ggtext::geom_textbox` or `ggtext::geom_richtext` might be needed for complex geoms,
#' but for `labs()` elements, `theme_markdown` is often sufficient.
#'
#' @param base_size_px Base font size in pixels (default 14px for desktop, 12px for mobile).
#'   This will be directly used where `element_markdown` supports pixel sizes.
#'   For elements still using `element_text` or where `rel()` is used with `element_markdown`,
#'   this acts more like a reference point.
#' @param base_family Base font family. Defaults to "Roboto".
#' @param target_device A character string: "desktop" (default) or "mobile".
#'   Influences default `base_size_px` and relative text size multipliers.
#'
#' @return A `ggplot2::theme` object.
#'
#' @export
#' @importFrom ggplot2 theme_minimal theme element_rect rel margin unit
#' @importFrom ggtext element_markdown
#' @importFrom systemfonts system_fonts
#'
#' @examples
#' library(ggplot2)
#' library(ggtext) # For markdown elements
#'
#' # --- Optional: Showtext for Roboto if not system-installed ---
#' #
#' \dontrun{
#' #   library(showtext)
#' #   font_add_google("Roboto", "Roboto")
#' #   showtext_auto()
#' #
#' }
#'
#' data(mpg, package = "ggplot2")
#' p_base <- ggplot(mpg, aes(x = displ, y = hwy)) +
#'   geom_point(aes(color = factor(cyl)), alpha = 0.7)
#'
#' # --- Desktop Example with Markdown ---
#' p_desk_md <- p_base +
#'   theme_kjn_markdown(target_device = "desktop") +
#'   labs(
#'     title = "Fuel Efficiency <b style='font-size:22px; color:#0072B2;'>Analysis</b>",
#'     subtitle = "Investigating the relationship between *engine displacement* and <i>highway MPG</i>.<br>Data from 1999 and 2008.",
#'     x = "Engine Displacement (<span style='font-style:italic;'>Liters</span>)",
#'     y = "Highway <span style='font-weight:bold;'>MPG</span>",
#'     caption = "Source: <span style='color:gray;'>ggplot2 mpg dataset</span> | Chart: KJN",
#'     color = "<b style='font-size:11px'>Cylinders:</b>"
#'   )
#' print(p_desk_md)
#'
#' # --- Mobile Example with Markdown ---
#' p_mob_md <- p_base +
#'   theme_kjn_markdown(target_device = "mobile") +
#'   labs(
#'     title = "Fuel Efficiency <b style='font-size:18px; color:#D55E00;'>Analysis</b>",
#'     subtitle = "Engine displacement vs. <i>highway MPG</i>.<br>Data: 1999 & 2008.",
#'     x = "Displacement (<span style='font-style:italic;'>L</span>)",
#'     y = "<span style='font-weight:bold;'>MPG</span> (Highway)",
#'     caption = "Source: <span style='color:gray;'>mpg data</span> | KJN",
#'     color = "<b style='font-size:10px'>Cyl.:</b>"
#'   )
#' print(p_mob_md)
theme_kjn <- function(base_size_px = NULL,
                      base_family = "Roboto",
                      target_device = "desktop") {
  # --- 1. Determine Base Pixel Size and Relative Multipliers ---
  is_mobile <- tolower(target_device) == "mobile"
  is_desktop <- tolower(target_device) == "desktop"

  if (is.null(base_size_px)) {
    if (is_mobile) {
      final_base_size_px_val <- 12 # Base for mobile in px
    } else if (is_desktop) {
      final_base_size_px_val <- 14 # Base for desktop in px
    } else {
      warning("Invalid 'target_device': \"", target_device,
        "\". Defaulting to 'desktop' base size (14px).",
        call. = FALSE
      )
      final_base_size_px_val <- 14
      is_desktop <- TRUE
      is_mobile <- FALSE
    }
  } else {
    final_base_size_px_val <- base_size_px
  }

  # Relative text size multipliers (can be used with element_markdown's size if not using direct px)
  # Or used to calculate absolute pixel sizes from final_base_size_px_val
  if (is_mobile) {
    title_size_px <- round(final_base_size_px_val * 1.5) # e.g., 12 * 1.5 = 18px
    subtitle_size_px <- round(final_base_size_px_val * 1.1) # e.g., 12 * 1.1 = 13px
    caption_size_px <- round(final_base_size_px_val * 0.8) # e.g., 12 * 0.8 = 10px
    axis_title_size_px <- round(final_base_size_px_val * 1.0) # e.g., 12px
    axis_text_size_px <- round(final_base_size_px_val * 0.85) # e.g., 10px
    legend_title_size_px <- round(final_base_size_px_val * 0.9) # e.g., 11px
    legend_text_size_px <- round(final_base_size_px_val * 0.8) # e.g., 10px
  } else { # Desktop
    title_size_px <- round(final_base_size_px_val * 1.6) # e.g., 14 * 1.6 = 22px
    subtitle_size_px <- round(final_base_size_px_val * 1.2) # e.g., 14 * 1.2 = 17px
    caption_size_px <- round(final_base_size_px_val * 0.85) # e.g., 12px
    axis_title_size_px <- round(final_base_size_px_val * 1.05) # e.g., 15px
    axis_text_size_px <- round(final_base_size_px_val * 0.9) # e.g., 13px
    legend_title_size_px <- round(final_base_size_px_val * 1.0) # e.g., 14px
    legend_text_size_px <- round(final_base_size_px_val * 0.9) # e.g., 13px
  }

  # --- 2. Font Check (Informational) ---
  available_system_fonts <- systemfonts::system_fonts()$family
  if (!(base_family %in% available_system_fonts) && !identical(base_family, "")) {
    message(
      "Font '", base_family, "' was not found among system fonts. ",
      "ggplot2 may fall back to a default sans-serif font. \n",
      "For best results with '", base_family, "', ensure it is installed system-wide. \n",
      "Alternatively, for 'Roboto' or other Google Fonts, consider using 'showtext': \n",
      "  library(showtext); font_add_google('", base_family, "', '", base_family, "'); showtext_auto()"
    )
  }

  # --- 3. Determine Plot Margins ---
  plot_margin_val <- if (is_mobile) {
    ggplot2::margin(7, 7, 7, 7) # Slightly adjusted margins
  } else {
    ggplot2::margin(12, 12, 12, 12)
  }

  # Using theme_minimal's base_size as a reference for non-markdown elements (lines, rects)
  # We use our final_base_size_px_val to define a points equivalent for theme_minimal
  # 1 px approx 0.75 pt. So if final_base_size_px_val is 14px, it's roughly 10.5pt.
  # This is just for theme_minimal's own scaling of non-text elements.
  # Our markdown text sizes will be absolute pixels.
  reference_base_size_pt <- final_base_size_px_val * 0.75

  # --- 4. Build Theme ---
  ggplot2::theme_minimal(
    base_size = reference_base_size_pt, # For theme_minimal's internal scaling
    base_family = base_family # Default family for theme_minimal
  ) +
    ggplot2::theme(
      # REMOVE the global 'text = element_markdown(...)' line.
      # Let theme_minimal set the base text properties with element_text.
      # We will override specific elements below with element_markdown.

      # --- TEXT: Using element_markdown with pixel sizes for specific elements ---
      plot.title = ggtext::element_markdown(
        family = base_family, colour = "black", face = "bold",
        size = title_size_px, # Direct pixel size
        margin = ggplot2::margin(b = final_base_size_px_val * 0.5)
      ),
      plot.subtitle = ggtext::element_markdown(
        family = base_family, colour = "black",
        size = subtitle_size_px,
        lineheight = 1.1, # Often useful for multi-line subtitles
        margin = ggplot2::margin(b = final_base_size_px_val * 0.75)
      ),
      plot.caption = ggtext::element_markdown(
        family = base_family, colour = "black",
        size = caption_size_px, hjust = 1,
        margin = ggplot2::margin(t = final_base_size_px_val * 0.5)
      ),
      axis.title = ggtext::element_markdown( # For X and Y axis titles
        family = base_family, colour = "black",
        size = axis_title_size_px
      ),
      # axis.title.x = element_markdown(...), # If you need separate styling
      # axis.title.y = element_markdown(...),
      axis.text = ggtext::element_markdown( # For X and Y axis tick labels
        family = base_family, colour = "black",
        size = axis_text_size_px
      ),
      axis.text.x = ggtext::element_markdown(
        family = base_family, colour = "black", size = axis_text_size_px, # Be explicit
        margin = ggplot2::margin(t = final_base_size_px_val * 0.2)
      ),
      axis.text.y = ggtext::element_markdown(
        family = base_family, colour = "black", size = axis_text_size_px, # Be explicit
        margin = ggplot2::margin(r = final_base_size_px_val * 0.2)
      ),
      legend.title = ggtext::element_markdown(
        family = base_family, colour = "black", face = "bold",
        size = legend_title_size_px
      ),
      legend.text = ggtext::element_markdown(
        family = base_family, colour = "black",
        size = legend_text_size_px
      ),
      strip.text = ggtext::element_markdown( # For facet labels, if you use facets
        family = base_family, colour = "black", face = "bold",
        size = axis_title_size_px # Example: same size as axis titles
      ),


      # --- BACKGROUNDS ---
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      legend.key = ggplot2::element_rect(fill = "transparent", colour = NA),

      # --- LEGEND ---
      legend.position = "top",
      legend.box.margin = ggplot2::margin(t = 0, r = 0, b = -5, l = 0),

      # --- MARGINS ---
      plot.margin = plot_margin_val,
      complete = TRUE
    )
}
