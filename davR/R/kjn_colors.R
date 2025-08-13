#' KJN Color Palette
#'
#' Returns a named vector of colors used in KJN visualizations.
#'
#' @param names Character vector of color names to return. If NULL (default),
#'   returns all colors. Available colors: "nachtblau", "himmelblau", "eisblau",
#'   "feuerrot", "orange".
#' @param as_hex Logical. If TRUE (default), returns hex color codes.
#'   If FALSE, returns the named vector.
#'
#' @return A named character vector of hex color codes.
#'
#' @examples
#' # Get all colors
#' kjn_colors()
#'
#' # Get specific colors
#' kjn_colors(c("nachtblau", "orange"))
#'
#' # Use in ggplot
#' library(ggplot2)
#' ggplot(mtcars, aes(x = wt, y = mpg)) +
#'   geom_point(color = kjn_colors("feuerrot"))
#'
#' @export
kjn_colors <- function(names = NULL, as_hex = TRUE) {
    # Define the KJN color palette
    kjn_palette <- c(
        nachtblau = "#072e6b",
        himmelblau = "#9cc9e0",
        eisblau = "#e1edf7",
        feuerrot = "#a40f15",
        orange = "#fa6847"
    )

    # If no specific names requested, return all colors
    if (is.null(names)) {
        return(kjn_palette)
    }

    # Validate requested color names
    invalid_names <- names[!names %in% names(kjn_palette)]
    if (length(invalid_names) > 0) {
        stop(
            "Invalid color names: ",
            paste(invalid_names, collapse = ", "),
            "\nAvailable colors: ",
            paste(names(kjn_palette), collapse = ", ")
        )
    }

    # Return requested colors
    requested_colors <- kjn_palette[names]

    if (!as_hex) {
        return(requested_colors)
    }

    return(requested_colors)
}

#' Show KJN Color Palette
#'
#' Displays the KJN color palette visually using base R plotting.
#'
#' @param labels Logical. If TRUE (default), shows color names and hex codes.
#'
#' @examples
#' # Show the palette
#' show_kjn_colors()
#'
#' # Show without labels
#' show_kjn_colors(labels = FALSE)
#'
#' @export
show_kjn_colors <- function(labels = TRUE) {
    colors <- kjn_colors()
    n_colors <- length(colors)

    # Set up the plot
    par(mar = c(1, 4, 1, 1))
    plot(
        1:n_colors,
        rep(1, n_colors),
        col = colors,
        pch = 15,
        cex = 8,
        xlim = c(0.5, n_colors + 0.5),
        ylim = c(0.5, 1.5),
        xlab = "",
        ylab = "",
        xaxt = "n",
        yaxt = "n",
        main = "KJN Color Palette"
    )

    if (labels) {
        # Add color names below
        text(
            1:n_colors,
            rep(0.7, n_colors),
            labels = names(colors),
            srt = 45,
            adj = c(1, 0.5),
            cex = 0.8
        )

        # Add hex codes above
        text(
            1:n_colors,
            rep(1.3, n_colors),
            labels = colors,
            srt = 45,
            adj = c(0, 0.5),
            cex = 0.7,
            family = "mono"
        )
    }
}

#' Get KJN Color Scale for ggplot2
#'
#' Returns a ggplot2 color scale using KJN colors.
#'
#' @param discrete Logical. If TRUE, returns scale_color_manual for discrete data.
#'   If FALSE, returns scale_color_gradientn for continuous data.
#' @param reverse Logical. If TRUE, reverses the color order.
#' @param ... Additional arguments passed to the ggplot2 scale function.
#'
#' @return A ggplot2 scale function.
#'
#' @examples
#' library(ggplot2)
#'
#' # For discrete data
#' ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) +
#'   geom_point() +
#'   scale_kjn_colors()
#'
#' # For continuous data
#' ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Petal.Length)) +
#'   geom_point() +
#'   scale_kjn_colors(discrete = FALSE)
#'
#' @export
scale_kjn_colors <- function(discrete = TRUE, reverse = FALSE, ...) {
    colors <- kjn_colors()

    if (reverse) {
        colors <- rev(colors)
    }

    if (discrete) {
        ggplot2::scale_color_manual(values = colors, ...)
    } else {
        ggplot2::scale_color_gradientn(colors = colors, ...)
    }
}

#' Get KJN Fill Scale for ggplot2
#'
#' Returns a ggplot2 fill scale using KJN colors.
#'
#' @param discrete Logical. If TRUE, returns scale_fill_manual for discrete data.
#'   If FALSE, returns scale_fill_gradientn for continuous data.
#' @param reverse Logical. If TRUE, reverses the color order.
#' @param ... Additional arguments passed to the ggplot2 scale function.
#'
#' @return A ggplot2 scale function.
#'
#' @examples
#' library(ggplot2)
#'
#' # For discrete data
#' ggplot(iris, aes(x = Species, fill = Species)) +
#'   geom_bar() +
#'   scale_kjn_fill()
#'
#' @export
scale_kjn_fill <- function(discrete = TRUE, reverse = FALSE, ...) {
    colors <- kjn_colors()

    if (reverse) {
        colors <- rev(colors)
    }

    if (discrete) {
        ggplot2::scale_fill_manual(values = colors, ...)
    } else {
        ggplot2::scale_fill_gradientn(colors = colors, ...)
    }
}
