# Find Optimal Contrasting Colors

Calculates optimal contrasting colors for a given background color.
Provides multiple contrast options with accessibility ratings.

## Usage

``` r
find_contrast_color(
  background_color,
  contrast_level = "AA",
  color_type = "all"
)
```

## Arguments

- background_color:

  Character. Hex color code (e.g., "#C1D9D9").

- contrast_level:

  Character. Desired contrast level: "AA" (4.5:1), "AAA" (7:1), or
  "high" (10:1+). Default is "AA".

- color_type:

  Character. Type of contrasting color: "dark", "light",
  "complementary", or "all". Default is "all".

## Value

A list with:

- background: Original background color

- contrasts: Named vector of contrasting colors with contrast ratios

- recommendations: Best options for different use cases

- accessibility: WCAG compliance information

## Examples

``` r
# Find contrasting colors for apo ressort
find_contrast_color("#C1D9D9")
#> $background
#> [1] "#C1D9D9"
#> 
#> $contrasts
#> $contrasts$black
#> [1] "#000000"
#> 
#> $contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $contrasts$complementary
#> [1] "#3E2626"
#> 
#> $contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          14.194584          14.194584           9.400013           9.342820 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           8.019895           7.424016           6.723119           6.278954 
#>          dark_blue         dark_green 
#>           5.894819           5.319231 
#> 
#> $recommendations
#> $recommendations$best_overall
#> [1] "black"
#> 
#> $recommendations$best_dark
#> [1] "black"
#> 
#> $recommendations$best_light
#> [1] NA
#> 
#> $recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $accessibility
#> $accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $accessibility$highest_contrast
#> [1] 14.19458
#> 
#> $accessibility$background_luminance
#> [1] 0.6597292
#> 
#> 

# Get only dark contrasting colors
find_contrast_color("#C1D9D9", color_type = "dark")
#> $background
#> [1] "#C1D9D9"
#> 
#> $contrasts
#> $contrasts$black
#> [1] "#000000"
#> 
#> $contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $contrast_ratios
#>         black    dark_brown   dark_purple     dark_navy      dark_red 
#>     14.194584      9.342820      8.019895      7.424016      6.723119 
#> dark_charcoal     dark_blue    dark_green 
#>      6.278954      5.894819      5.319231 
#> 
#> $recommendations
#> $recommendations$best_overall
#> [1] "black"
#> 
#> $recommendations$best_dark
#> [1] "black"
#> 
#> $recommendations$best_light
#> [1] NA
#> 
#> $recommendations$complementary
#> NULL
#> 
#> 
#> $accessibility
#> $accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $accessibility$highest_contrast
#> [1] 14.19458
#> 
#> $accessibility$background_luminance
#> [1] 0.6597292
#> 
#> 

# Get high contrast options
find_contrast_color("#C1D9D9", contrast_level = "high")
#> $background
#> [1] "#C1D9D9"
#> 
#> $contrasts
#> $contrasts$black
#> [1] "#000000"
#> 
#> $contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> 
#> $contrast_ratios
#>              black high_contrast_dark 
#>           14.19458           14.19458 
#> 
#> $recommendations
#> $recommendations$best_overall
#> [1] "black"
#> 
#> $recommendations$best_dark
#> [1] "black"
#> 
#> $recommendations$best_light
#> [1] NA
#> 
#> $recommendations$complementary
#> NULL
#> 
#> 
#> $accessibility
#> $accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $accessibility$highest_contrast
#> [1] 14.19458
#> 
#> $accessibility$background_luminance
#> [1] 0.6597292
#> 
#> 
```
