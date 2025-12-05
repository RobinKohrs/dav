#' Nice Color Palettes with Contrasting Colors
#'
#' Returns curated color palettes with contrasting colors for each main color.
#' Each palette includes a main color and its contrasting color for optimal readability.
#'
#' @param palette Character. Name of the palette to return. Available palettes:
#'   "modern", "vibrant", "pastel", "professional", "nature", "sunset", "ocean", "newspaper".
#'   If NULL (default), returns all palettes.
#' @param include_contrasts Logical. If TRUE (default), includes contrasting colors.
#'   If FALSE, returns only main colors.
#'
#' @return A list containing color palettes. Each palette is a list with:
#'   - main: Named vector of main colors
#'   - contrast: Named vector of contrasting colors
#'   - description: Description of the palette
#'
#' @examples
#' # Get all palettes
#' nice_colors()
#'
#' # Get specific palette
#' nice_colors("modern")
#'
#' # Get only main colors without contrasts
#' nice_colors("vibrant", include_contrasts = FALSE)
#'
#' # Use in ggplot
#' library(ggplot2)
#' colors <- nice_colors("modern")
#' ggplot(mtcars, aes(x = wt, y = mpg, color = factor(cyl))) +
#'   geom_point() +
#'   scale_color_manual(values = colors$main)
#'
#' # Use newspaper colors
#' newspaper_colors <- nice_colors("newspaper")
#' ggplot(mtcars, aes(x = wt, y = mpg, color = factor(cyl))) +
#'   geom_point() +
#'   scale_color_manual(values = newspaper_colors$main)
#'
#' @export
nice_colors <- function(palette = NULL, include_contrasts = TRUE) {
    # Define color palettes with main and contrasting colors
    palettes <- list(
        observable10 = list(
            main = c(
                blue = "#4269d0",
                orange = "#efb118",
                red = "#ff725c",
                cyan = "#6cc5b0",
                green = "#3ca951",
                purple = "#ff8ab7",
                fuchsia = "#a463f2",
                brown = "#97bbf5",
                gray = "#9c6b4e",
                light_gray = "#9498a0"
            ),
            description = "The Observable 10 palette: A contemporary categorical color scheme designed for data visualization."
        ),
        retro_metro = list(
            main = c(
                red = "#ea5545",
                pink = "#f46a9b",
                orange = "#ef9b20",
                yellow = "#edbf33",
                lime = "#ede15b",
                green = "#bdcf32",
                grass = "#87bc45",
                blue = "#27aeef",
                purple = "#b33dc6"
            ),
            description = "Retro Metro: A vibrant blend of lively and engaging colors."
        ),
        dutch_field = list(
            main = c(
                red = "#e60049",
                blue = "#0bb4ff",
                green = "#50e991",
                yellow = "#e6d800",
                purple = "#9b19f5",
                orange = "#ffa300",
                magenta = "#dc0ab4",
                light_blue = "#b3d4ff",
                teal = "#00bfa0"
            ),
            description = "Dutch Field: Bold colors for a modern look that pops."
        ),
        river_nights = list(
            main = c(
                red = "#b30000",
                maroon = "#7c1158",
                indigo = "#4421af",
                blue = "#1a53ff",
                sky = "#0d88e6",
                teal = "#00b7c7",
                green = "#5ad45a",
                lime = "#8be04e",
                yellow = "#ebdc78"
            ),
            description = "River Nights: Deeper hues for a sophisticated presentation."
        ),
        spring_pastels = list(
            main = c(
                pink = "#fd7f6f",
                blue = "#7eb0d5",
                green = "#b2e061",
                purple = "#bd7ebe",
                orange = "#ffb55a",
                yellow = "#ffee65",
                lavender = "#beb9db",
                rose = "#fdcce5",
                mint = "#8bd3c7"
            ),
            description = "Spring Pastels: Soft, lighter colors for a soothing look."
        ),
        modern = list(
            main = c(
                purple = "#5856D6",
                teal = "#5AC8FA",
                green = "#34C759",
                orange = "#FF9500",
                red = "#FF3B30",
                yellow = "#FFCC00",
                pink = "#FF2D92",
                indigo = "#007AFF"
            ),
            description = "Modern iOS-inspired colors with high contrast"
        ),

        vibrant = list(
            main = c(
                electric_blue = "#5856D6",
                coral = "#FF6B6B",
                lime = "#4ECDC4",
                gold = "#FFE66D",
                magenta = "#A8E6CF",
                violet = "#B4A7D6",
                salmon = "#FFB3BA",
                mint = "#BAFFC9"
            ),
            description = "Vibrant and energetic colors"
        ),

        pastel = list(
            main = c(
                lavender = "#E6E6FA",
                peach = "#FFDAB9",
                mint = "#F0FFF0",
                rose = "#FFE4E1",
                sky = "#E0F6FF",
                cream = "#FFF8DC",
                lilac = "#DDA0DD",
                powder_blue = "#B0E0E6"
            ),
            description = "Soft pastel colors with dark contrasts"
        ),

        professional = list(
            main = c(
                navy = "#2C3E50",
                steel_blue = "#5856D6",
                charcoal = "#34495E",
                slate = "#7F8C8D",
                forest = "#27AE60",
                burgundy = "#8E44AD",
                bronze = "#D35400",
                steel = "#95A5A6"
            ),
            description = "Professional and corporate colors"
        ),

        nature = list(
            main = c(
                forest_green = "#2E8B57",
                earth_brown = "#8B4513",
                sky_blue = "#87CEEB",
                sunset_orange = "#FF6347",
                leaf_green = "#32CD32",
                bark_brown = "#A0522D",
                ocean_blue = "#4682B4",
                moss_green = "#9ACD32"
            ),
            description = "Natural earth and sky tones"
        ),

        sunset = list(
            main = c(
                deep_purple = "#5856D6",
                coral_pink = "#FF7F7F",
                golden_yellow = "#FFD700",
                burnt_orange = "#FF8C00",
                crimson = "#DC143C",
                lavender = "#E6E6FA",
                peach = "#FFCCCB",
                rose_gold = "#E8B4B8"
            ),
            description = "Warm sunset and twilight colors"
        ),

        ocean = list(
            main = c(
                deep_blue = "#5856D6",
                aqua = "#00FFFF",
                teal = "#008080",
                navy = "#000080",
                seafoam = "#7FFFD4",
                coral = "#FF7F50",
                pearl = "#F0F8FF",
                wave = "#4682B4"
            ),
            description = "Ocean and marine-inspired colors"
        ),

        newspaper = list(
            main = c(
                apo = "#C1D9D9",
                wirt = "#D8DEC1",
                sport = "#C6DC73",
                pano = "#AFD4AE",
                kultur = "#D2D0CF",
                etat = "#FFCC66",
                wiss = "#BEDAE3",
                karriere = "#F8F8F8",
                zukunft = "#E6E6E6"
            ),
            description = "Newspaper-themed colors with WCAG AA compliant contrasts"
        )
    )

    # Automatically calculate contrasts for palettes where they are not explicitly defined
    for (name in names(palettes)) {
        if (is.null(palettes[[name]]$contrast)) {
            palettes[[name]]$contrast <- sapply(
                palettes[[name]]$main,
                function(hex) {
                    # Calculate luminance to decide between black and white
                    rgb <- col2rgb(hex)
                    # Perceived brightness formula
                    lum <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) /
                        255
                    if (lum > 0.5) "#000000" else "#FFFFFF"
                }
            )
        }
    }

    # If no specific palette requested, return all
    if (is.null(palette)) {
        if (!include_contrasts) {
            # Return only main colors for all palettes
            result <- lapply(palettes, function(x) {
                list(
                    main = x$main,
                    description = x$description
                )
            })
        } else {
            result <- palettes
        }
        return(result)
    }

    # Validate palette name
    if (!palette %in% names(palettes)) {
        stop(
            "Invalid palette name: ",
            palette,
            "\nAvailable palettes: ",
            paste(names(palettes), collapse = ", ")
        )
    }

    # Return requested palette
    selected_palette <- palettes[[palette]]

    if (!include_contrasts) {
        return(list(
            main = selected_palette$main,
            description = selected_palette$description
        ))
    }

    return(selected_palette)
}

#' Show Nice Color Palettes
#'
#' Displays color palettes visually using base R plotting.
#'
#' @param palette Character. Name of the palette to display. If NULL (default),
#'   displays all palettes.
#' @param show_contrasts Logical. If TRUE (default), shows contrasting colors.
#'
#' @examples
#' # Show all palettes
#' show_nice_colors()
#'
#' # Show specific palette
#' show_nice_colors("modern")
#'
#' # Show without contrasts
#' show_nice_colors("vibrant", show_contrasts = FALSE)
#'
#' @export
show_nice_colors <- function(palette = NULL, show_contrasts = TRUE) {
    colors_data <- nice_colors(palette, include_contrasts = show_contrasts)

    if (is.null(palette)) {
        # Show all palettes
        n_palettes <- length(colors_data)
        par(mfrow = c(ceiling(n_palettes / 2), 2), mar = c(2, 2, 2, 2))

        for (i in seq_along(colors_data)) {
            palette_name <- names(colors_data)[i]
            palette_data <- colors_data[[i]]

            main_colors <- palette_data$main
            n_colors <- length(main_colors)

            plot(
                1:n_colors,
                rep(1, n_colors),
                col = main_colors,
                pch = 15,
                cex = 3,
                xlim = c(0.5, n_colors + 0.5),
                ylim = c(0.5, 1.5),
                xlab = "",
                ylab = "",
                xaxt = "n",
                yaxt = "n",
                main = paste0(
                    toupper(substr(palette_name, 1, 1)),
                    substr(palette_name, 2, nchar(palette_name))
                )
            )

            if (show_contrasts && "contrast" %in% names(palette_data)) {
                contrast_colors <- palette_data$contrast
                points(
                    1:n_colors,
                    rep(0.7, n_colors),
                    col = contrast_colors,
                    pch = 15,
                    cex = 2
                )
            }
        }
    } else {
        # Show single palette
        palette_data <- colors_data
        main_colors <- palette_data$main
        n_colors <- length(main_colors)

        par(mar = c(3, 4, 3, 1))
        plot(
            1:n_colors,
            rep(1, n_colors),
            col = main_colors,
            pch = 15,
            cex = 4,
            xlim = c(0.5, n_colors + 0.5),
            ylim = c(0.5, 1.5),
            xlab = "",
            ylab = "",
            xaxt = "n",
            yaxt = "n",
            main = paste0(
                toupper(substr(palette, 1, 1)),
                substr(palette, 2, nchar(palette)),
                " Palette"
            )
        )

        # Add color names
        text(
            1:n_colors,
            rep(0.7, n_colors),
            labels = names(main_colors),
            srt = 45,
            adj = c(1, 0.5),
            cex = 0.8
        )

        if (show_contrasts && "contrast" %in% names(palette_data)) {
            contrast_colors <- palette_data$contrast
            points(
                1:n_colors,
                rep(0.7, n_colors),
                col = contrast_colors,
                pch = 15,
                cex = 2
            )
        }
    }

    par(mfrow = c(1, 1), mar = c(5, 4, 4, 2) + 0.1) # Reset to default
}

#' Get Nice Color Scale for ggplot2
#'
#' Returns a ggplot2 color scale using nice color palettes.
#'
#' @param palette Character. Name of the palette to use.
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
#'   scale_nice_colors("modern")
#'
#' # For continuous data
#' ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Petal.Length)) +
#'   geom_point() +
#'   scale_nice_colors("vibrant", discrete = FALSE)
#'
#' @export
scale_nice_colors <- function(
    palette = "modern",
    discrete = TRUE,
    reverse = FALSE,
    ...
) {
    colors_data <- nice_colors(palette, include_contrasts = FALSE)
    colors <- colors_data$main

    if (reverse) {
        colors <- rev(colors)
    }

    if (discrete) {
        ggplot2::scale_color_manual(values = colors, ...)
    } else {
        ggplot2::scale_color_gradientn(colors = colors, ...)
    }
}

#' Get Nice Fill Scale for ggplot2
#'
#' Returns a ggplot2 fill scale using nice color palettes.
#'
#' @param palette Character. Name of the palette to use.
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
#'   scale_nice_fill("nature")
#'
#' @export
scale_nice_fill <- function(
    palette = "modern",
    discrete = TRUE,
    reverse = FALSE,
    ...
) {
    colors_data <- nice_colors(palette, include_contrasts = FALSE)
    colors <- colors_data$main

    if (reverse) {
        colors <- rev(colors)
    }

    if (discrete) {
        ggplot2::scale_fill_manual(values = colors, ...)
    } else {
        ggplot2::scale_fill_gradientn(colors = colors, ...)
    }
}

#' Find Optimal Contrasting Colors
#'
#' Calculates optimal contrasting colors for a given background color.
#' Provides multiple contrast options with accessibility ratings.
#'
#' @param background_color Character. Hex color code (e.g., "#C1D9D9").
#' @param contrast_level Character. Desired contrast level: "AA" (4.5:1),
#'   "AAA" (7:1), or "high" (10:1+). Default is "AA".
#' @param color_type Character. Type of contrasting color: "dark", "light",
#'   "complementary", or "all". Default is "all".
#'
#' @return A list with:
#'   - background: Original background color
#'   - contrasts: Named vector of contrasting colors with contrast ratios
#'   - recommendations: Best options for different use cases
#'   - accessibility: WCAG compliance information
#'
#' @examples
#' # Find contrasting colors for apo ressort
#' find_contrast_color("#C1D9D9")
#'
#' # Get only dark contrasting colors
#' find_contrast_color("#C1D9D9", color_type = "dark")
#'
#' # Get high contrast options
#' find_contrast_color("#C1D9D9", contrast_level = "high")
#'
#' @export
find_contrast_color <- function(
    background_color,
    contrast_level = "AA",
    color_type = "all"
) {
    # Validate input
    if (!grepl("^#[0-9A-Fa-f]{6}$", background_color)) {
        stop(
            "background_color must be a valid hex color code (e.g., '#C1D9D9')"
        )
    }

    # Convert hex to RGB
    hex_to_rgb <- function(hex) {
        hex <- gsub("#", "", hex)
        r <- strtoi(substr(hex, 1, 2), 16)
        g <- strtoi(substr(hex, 3, 4), 16)
        b <- strtoi(substr(hex, 5, 6), 16)
        return(c(r, g, b))
    }

    # Convert RGB to hex
    rgb_to_hex <- function(rgb) {
        sprintf("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
    }

    # Calculate relative luminance
    get_luminance <- function(rgb) {
        rgb_norm <- rgb / 255
        rgb_norm <- ifelse(
            rgb_norm <= 0.03928,
            rgb_norm / 12.92,
            ((rgb_norm + 0.055) / 1.055)^2.4
        )
        return(
            0.2126 * rgb_norm[1] + 0.7152 * rgb_norm[2] + 0.0722 * rgb_norm[3]
        )
    }

    # Calculate contrast ratio
    get_contrast_ratio <- function(color1, color2) {
        lum1 <- get_luminance(hex_to_rgb(color1))
        lum2 <- get_luminance(hex_to_rgb(color2))
        lighter <- max(lum1, lum2)
        darker <- min(lum1, lum2)
        return((lighter + 0.05) / (darker + 0.05))
    }

    # Generate contrasting colors
    bg_rgb <- hex_to_rgb(background_color)
    bg_luminance <- get_luminance(bg_rgb)

    # Define contrast options
    contrast_options <- list(
        # Dark options
        dark_navy = "#2C3E50",
        dark_charcoal = "#34495E",
        dark_blue = "#1B4F72",
        dark_green = "#1B5E20",
        dark_red = "#7B241C",
        dark_purple = "#4A148C",
        dark_brown = "#3E2723",
        black = "#000000",

        # Light options
        white = "#FFFFFF",
        light_gray = "#F8F9FA",
        cream = "#FFF8DC",
        light_blue = "#E3F2FD",
        light_green = "#E8F5E8",
        light_yellow = "#FFFDE7",
        light_pink = "#FCE4EC",
        light_purple = "#F3E5F5",

        # Complementary colors (opposite on color wheel)
        complementary = rgb_to_hex(c(
            255 - bg_rgb[1],
            255 - bg_rgb[2],
            255 - bg_rgb[3]
        )),

        # High contrast options
        high_contrast_dark = if (bg_luminance > 0.5) "#000000" else "#FFFFFF",
        high_contrast_light = if (bg_luminance > 0.5) "#FFFFFF" else "#000000"
    )

    # Calculate contrast ratios
    contrast_ratios <- sapply(contrast_options, function(color) {
        get_contrast_ratio(background_color, color)
    })

    # Filter by contrast level
    min_ratio <- switch(
        contrast_level,
        "AA" = 4.5,
        "AAA" = 7.0,
        "high" = 10.0,
        4.5
    )

    valid_contrasts <- contrast_ratios[contrast_ratios >= min_ratio]

    # Filter by color type
    if (color_type == "dark") {
        dark_colors <- c(
            "dark_navy",
            "dark_charcoal",
            "dark_blue",
            "dark_green",
            "dark_red",
            "dark_purple",
            "dark_brown",
            "black"
        )
        valid_contrasts <- valid_contrasts[
            names(valid_contrasts) %in% dark_colors
        ]
    } else if (color_type == "light") {
        light_colors <- c(
            "white",
            "light_gray",
            "cream",
            "light_blue",
            "light_green",
            "light_yellow",
            "light_pink",
            "light_purple"
        )
        valid_contrasts <- valid_contrasts[
            names(valid_contrasts) %in% light_colors
        ]
    }

    # Sort by contrast ratio (highest first)
    valid_contrasts <- sort(valid_contrasts, decreasing = TRUE)

    # Get the actual colors
    contrast_colors <- contrast_options[names(valid_contrasts)]

    # Create recommendations
    recommendations <- list(
        best_overall = names(valid_contrasts)[1],
        best_dark = names(valid_contrasts[grepl(
            "dark|black",
            names(valid_contrasts)
        )])[1],
        best_light = names(valid_contrasts[grepl(
            "light|white",
            names(valid_contrasts)
        )])[1],
        complementary = if ("complementary" %in% names(valid_contrasts)) {
            "complementary"
        } else {
            NULL
        }
    )

    # Accessibility info
    accessibility <- list(
        wcag_aa_compliant = sum(contrast_ratios >= 4.5),
        wcag_aaa_compliant = sum(contrast_ratios >= 7.0),
        highest_contrast = max(contrast_ratios),
        background_luminance = bg_luminance
    )

    return(list(
        background = background_color,
        contrasts = contrast_colors,
        contrast_ratios = valid_contrasts,
        recommendations = recommendations,
        accessibility = accessibility
    ))
}

#' Visualize Color Contrasts
#'
#' Shows a visual comparison of a background color with its contrasting options.
#'
#' @param background_color Character. Hex color code.
#' @param contrast_level Character. Contrast level to show.
#' @param max_options Numeric. Maximum number of contrast options to display.
#'
#' @examples
#' # Visualize contrasts for apo color
#' visualize_contrasts("#C1D9D9")
#'
#' # Show only high contrast options
#' visualize_contrasts("#C1D9D9", contrast_level = "high")
#'
#' @export
visualize_contrasts <- function(
    background_color,
    contrast_level = "AA",
    max_options = 8
) {
    contrast_data <- find_contrast_color(background_color, contrast_level)

    # Get top contrast options
    top_contrasts <- head(contrast_data$contrasts, max_options)
    top_ratios <- head(contrast_data$contrast_ratios, max_options)

    n_options <- length(top_contrasts)

    # Set up plot
    par(mar = c(2, 8, 3, 2))
    plot(
        1,
        type = "n",
        xlim = c(0, n_options + 1),
        ylim = c(0, 2),
        xlab = "",
        ylab = "",
        main = paste("Contrast Options for", background_color),
        xaxt = "n",
        yaxt = "n"
    )

    # Draw background color
    rect(0, 1.5, n_options + 1, 2, col = background_color, border = NA)
    text(
        n_options / 2 + 0.5,
        1.75,
        "Background Color",
        col = contrast_data$contrasts[1],
        font = 2,
        cex = 1.2
    )

    # Draw contrast options
    for (i in seq_along(top_contrasts)) {
        x_pos <- i
        contrast_color <- top_contrasts[i]
        contrast_ratio <- top_ratios[i]

        # Draw contrast color
        rect(
            x_pos - 0.4,
            0.5,
            x_pos + 0.4,
            1.2,
            col = contrast_color,
            border = "black"
        )

        # Add text on contrast color
        text(
            x_pos,
            0.85,
            names(top_contrasts)[i],
            col = background_color,
            cex = 0.7,
            font = 2
        )

        # Add contrast ratio
        text(
            x_pos,
            0.65,
            sprintf("%.1f:1", contrast_ratio),
            col = background_color,
            cex = 0.6
        )
    }

    # Add legend
    legend(
        "bottom",
        legend = c("WCAG AA: 4.5:1+", "WCAG AAA: 7:1+", "High: 10:1+"),
        fill = c("#90EE90", "#87CEEB", "#FFB6C1"),
        horiz = TRUE,
        cex = 0.8
    )
}

#' Find Contrasting Colors for DST Newspaper Ressorts
#'
#' Automatically finds optimal contrasting colors for DST newspaper ressort colors.
#' Uses the predefined newspaper color palette and calculates the best contrasting options.
#'
#' @param ressort Character. Name of the ressort: "apo", "wirt", "sport", "pano",
#'   "kultur", "etat", "wiss", "karriere", "zukunft". If NULL, returns all ressort contrasts.
#' @param contrast_level Character. Desired contrast level: "AA" (4.5:1),
#'   "AAA" (7:1), or "high" (10:1+). Default is "AA".
#' @param color_type Character. Type of contrasting color: "dark", "light",
#'   "complementary", or "all". Default is "all".
#'
#' @return A list with:
#'   - ressort: Name of the ressort
#'   - background_color: The ressort's background color
#'   - contrasts: Named vector of contrasting colors with contrast ratios
#'   - recommendations: Best options for different use cases
#'   - accessibility: WCAG compliance information
#'
#' @examples
#' # Find contrasting colors for apo ressort
#' find_contrast_color_dst("apo")
#'
#' # Get all ressort contrasts
#' find_contrast_color_dst()
#'
#' # Get only dark contrasting colors for sport ressort
#' find_contrast_color_dst("sport", color_type = "dark")
#'
#' # Get high contrast options for wirt ressort
#' find_contrast_color_dst("wirt", contrast_level = "high")
#'
#' @export
find_contrast_color_dst <- function(
    ressort = NULL,
    contrast_level = "AA",
    color_type = "all"
) {
    # Get newspaper colors
    newspaper_colors <- nice_colors("newspaper", include_contrasts = FALSE)
    dst_colors <- newspaper_colors$main

    # Validate ressort name
    if (!is.null(ressort)) {
        if (!ressort %in% names(dst_colors)) {
            stop(
                "Invalid ressort name: ",
                ressort,
                "\nAvailable ressorts: ",
                paste(names(dst_colors), collapse = ", ")
            )
        }
    }

    # If no specific ressort requested, return all
    if (is.null(ressort)) {
        result <- list()
        for (ressort_name in names(dst_colors)) {
            result[[ressort_name]] <- find_contrast_color(
                dst_colors[ressort_name],
                contrast_level = contrast_level,
                color_type = color_type
            )
            result[[ressort_name]]$ressort <- ressort_name
        }
        return(result)
    }

    # Get contrasting colors for specific ressort
    background_color <- dst_colors[ressort]
    contrast_result <- find_contrast_color(
        background_color,
        contrast_level = contrast_level,
        color_type = color_type
    )

    # Add ressort name to result
    contrast_result$ressort <- ressort

    return(contrast_result)
}

#' Visualize DST Ressort Contrasts
#'
#' Shows visual comparison of DST ressort colors with their contrasting options.
#'
#' @param ressort Character. Name of the ressort to visualize. If NULL,
#'   shows all ressorts in a grid.
#' @param contrast_level Character. Contrast level to show.
#' @param max_options Numeric. Maximum number of contrast options to display per ressort.
#'
#' @examples
#' # Visualize apo ressort contrasts
#' visualize_dst_contrasts("apo")
#'
#' # Show all ressorts
#' visualize_dst_contrasts()
#'
#' # Show only high contrast options for sport
#' visualize_dst_contrasts("sport", contrast_level = "high")
#'
#' @export
visualize_dst_contrasts <- function(
    ressort = NULL,
    contrast_level = "AA",
    max_options = 6
) {
    # Get newspaper colors
    newspaper_colors <- nice_colors("newspaper", include_contrasts = FALSE)
    dst_colors <- newspaper_colors$main

    if (is.null(ressort)) {
        # Show all ressorts in a grid
        n_ressorts <- length(dst_colors)
        n_cols <- ceiling(sqrt(n_ressorts))
        n_rows <- ceiling(n_ressorts / n_cols)

        par(mfrow = c(n_rows, n_cols), mar = c(1, 1, 2, 1))

        for (i in seq_along(dst_colors)) {
            ressort_name <- names(dst_colors)[i]
            background_color <- dst_colors[i]

            contrast_data <- find_contrast_color(
                background_color,
                contrast_level
            )
            top_contrasts <- head(contrast_data$contrasts, max_options)
            top_ratios <- head(contrast_data$contrast_ratios, max_options)

            n_options <- length(top_contrasts)

            # Set up plot
            plot(
                1,
                type = "n",
                xlim = c(0, n_options + 1),
                ylim = c(0, 2),
                xlab = "",
                ylab = "",
                main = paste(toupper(ressort_name), ressort_name),
                xaxt = "n",
                yaxt = "n"
            )

            # Draw background color
            rect(0, 1.5, n_options + 1, 2, col = background_color, border = NA)
            text(
                n_options / 2 + 0.5,
                1.75,
                toupper(ressort_name),
                col = top_contrasts[1],
                font = 2,
                cex = 1.0
            )

            # Draw contrast options
            for (j in seq_along(top_contrasts)) {
                x_pos <- j
                contrast_color <- top_contrasts[j]
                contrast_ratio <- top_ratios[j]

                # Draw contrast color
                rect(
                    x_pos - 0.3,
                    0.5,
                    x_pos + 0.3,
                    1.2,
                    col = contrast_color,
                    border = "black"
                )

                # Add contrast ratio
                text(
                    x_pos,
                    0.65,
                    sprintf("%.1f", contrast_ratio),
                    col = background_color,
                    cex = 0.5,
                    font = 2
                )
            }
        }

        par(mfrow = c(1, 1), mar = c(5, 4, 4, 2) + 0.1) # Reset to default
    } else {
        # Show single ressort
        if (!ressort %in% names(dst_colors)) {
            stop(
                "Invalid ressort name: ",
                ressort,
                "\nAvailable ressorts: ",
                paste(names(dst_colors), collapse = ", ")
            )
        }

        background_color <- dst_colors[ressort]
        visualize_contrasts(background_color, contrast_level, max_options)

        # Update title
        title(main = paste("DST", toupper(ressort), "Ressort Contrasts"))
    }
}

#' Get Best Contrasting Color for DST Ressort
#'
#' Quick helper function to get the single best contrasting color for a DST ressort.
#'
#' @param ressort Character. Name of the ressort.
#' @param contrast_level Character. Desired contrast level.
#' @param color_type Character. Type of contrasting color.
#'
#' @return Character. Hex color code of the best contrasting color.
#'
#' @examples
#' # Get best contrasting color for apo
#' get_best_dst_contrast("apo")
#'
#' # Get best dark contrasting color for sport
#' get_best_dst_contrast("sport", color_type = "dark")
#'
#' @export
get_best_dst_contrast <- function(
    ressort,
    contrast_level = "AA",
    color_type = "all"
) {
    contrast_data <- find_contrast_color_dst(
        ressort,
        contrast_level,
        color_type
    )
    best_option <- contrast_data$recommendations$best_overall
    return(contrast_data$contrasts[best_option])
}
