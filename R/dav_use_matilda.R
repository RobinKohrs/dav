#' Use STMatilda Fonts in ggplot2
#'
#' This function returns a ggplot2 theme component that sets the font family
#' to "STMatilda" (Text or Info variants). It is designed to be added to any
#' ggplot object or theme.
#'
#' @param type Character string, either "text" or "info". Determines which font family to use.
#'   Defaults to "text".
#'   \itemize{
#'     \item "text": Uses "STMatilda Text Variable Roman"
#'     \item "info": Uses "STMatilda Info Variable Roman"
#'   }
#' @param base_size Optional numeric. If provided, sets the base font size for the plot text.
#'
#' @return A \code{ggplot2::theme} object.
#' @export
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' # Use with default theme
#' ggplot(mtcars, aes(mpg, wt)) +
#'   geom_point() +
#'   labs(title = "Matilda Text Font") +
#'   dav_use_matilda("text")
#'
#' # Use with theme_kjn or others
#' ggplot(mtcars, aes(mpg, wt)) +
#'   geom_point() +
#'   labs(title = "Matilda Info Font") +
#'   theme_minimal() +
#'   dav_use_matilda("info", base_size = 14)
#' }
dav_use_matilda <- function(type = c("text", "info"), base_size = NULL) {
    type <- match.arg(type)

    font_family <- switch(
        type,
        "text" = "STMatilda Text Variable Roman",
        "info" = "STMatilda Info Variable Roman"
    )

    # Set the global text family. Most themes inherit from this.
    # We use update_geom_defaults implicitly by returning a theme that
    # sets the plot text properties.

    theme_args <- list(family = font_family)
    if (!is.null(base_size)) {
        theme_args$size <- base_size
    }

    ggplot2::theme(
        text = do.call(ggplot2::element_text, theme_args)
    )
}
