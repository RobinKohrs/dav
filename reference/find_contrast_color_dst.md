# Find Contrasting Colors for DST Newspaper Ressorts

Automatically finds optimal contrasting colors for DST newspaper ressort
colors. Uses the predefined newspaper color palette and calculates the
best contrasting options.

## Usage

``` r
find_contrast_color_dst(
  ressort = NULL,
  contrast_level = "AA",
  color_type = "all"
)
```

## Arguments

- ressort:

  Character. Name of the ressort: "apo", "wirt", "sport", "pano",
  "kultur", "etat", "wiss", "karriere", "zukunft". If NULL, returns all
  ressort contrasts.

- contrast_level:

  Character. Desired contrast level: "AA" (4.5:1), "AAA" (7:1), or
  "high" (10:1+). Default is "AA".

- color_type:

  Character. Type of contrasting color: "dark", "light",
  "complementary", or "all". Default is "all".

## Value

A list with:

- ressort: Name of the ressort

- background_color: The ressort's background color

- contrasts: Named vector of contrasting colors with contrast ratios

- recommendations: Best options for different use cases

- accessibility: WCAG compliance information

## Examples

``` r
# Find contrasting colors for apo ressort
find_contrast_color_dst("apo")
#> $background
#>       apo 
#> "#C1D9D9" 
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
#> $ressort
#> [1] "apo"
#> 

# Get all ressort contrasts
find_contrast_color_dst()
#> $apo
#> $apo$background
#>       apo 
#> "#C1D9D9" 
#> 
#> $apo$contrasts
#> $apo$contrasts$black
#> [1] "#000000"
#> 
#> $apo$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $apo$contrasts$complementary
#> [1] "#3E2626"
#> 
#> $apo$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $apo$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $apo$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $apo$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $apo$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $apo$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $apo$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $apo$contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          14.194584          14.194584           9.400013           9.342820 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           8.019895           7.424016           6.723119           6.278954 
#>          dark_blue         dark_green 
#>           5.894819           5.319231 
#> 
#> $apo$recommendations
#> $apo$recommendations$best_overall
#> [1] "black"
#> 
#> $apo$recommendations$best_dark
#> [1] "black"
#> 
#> $apo$recommendations$best_light
#> [1] NA
#> 
#> $apo$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $apo$accessibility
#> $apo$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $apo$accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $apo$accessibility$highest_contrast
#> [1] 14.19458
#> 
#> $apo$accessibility$background_luminance
#> [1] 0.6597292
#> 
#> 
#> $apo$ressort
#> [1] "apo"
#> 
#> 
#> $wirt
#> $wirt$background
#>      wirt 
#> "#D8DEC1" 
#> 
#> $wirt$contrasts
#> $wirt$contrasts$black
#> [1] "#000000"
#> 
#> $wirt$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $wirt$contrasts$complementary
#> [1] "#27213E"
#> 
#> $wirt$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $wirt$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $wirt$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $wirt$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $wirt$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $wirt$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $wirt$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $wirt$contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          15.138348          15.138348          11.022777           9.964001 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           8.553118           7.917621           7.170123           6.696426 
#>          dark_blue         dark_green 
#>           6.286751           5.672894 
#> 
#> $wirt$recommendations
#> $wirt$recommendations$best_overall
#> [1] "black"
#> 
#> $wirt$recommendations$best_dark
#> [1] "black"
#> 
#> $wirt$recommendations$best_light
#> [1] NA
#> 
#> $wirt$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $wirt$accessibility
#> $wirt$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $wirt$accessibility$wcag_aaa_compliant
#> [1] 7
#> 
#> $wirt$accessibility$highest_contrast
#> [1] 15.13835
#> 
#> $wirt$accessibility$background_luminance
#> [1] 0.7069174
#> 
#> 
#> $wirt$ressort
#> [1] "wirt"
#> 
#> 
#> $sport
#> $sport$background
#>     sport 
#> "#C6DC73" 
#> 
#> $sport$contrasts
#> $sport$contrasts$black
#> [1] "#000000"
#> 
#> $sport$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $sport$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $sport$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $sport$contrasts$complementary
#> [1] "#39238C"
#> 
#> $sport$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $sport$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $sport$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $sport$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $sport$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $sport$contrast_ratios
#>              black high_contrast_dark         dark_brown        dark_purple 
#>          13.885994          13.885994           9.139707           7.845542 
#>      complementary          dark_navy           dark_red      dark_charcoal 
#>           7.744239           7.262619           6.576959           6.142449 
#>          dark_blue         dark_green 
#>           5.766666           5.203591 
#> 
#> $sport$recommendations
#> $sport$recommendations$best_overall
#> [1] "black"
#> 
#> $sport$recommendations$best_dark
#> [1] "black"
#> 
#> $sport$recommendations$best_light
#> [1] NA
#> 
#> $sport$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $sport$accessibility
#> $sport$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $sport$accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $sport$accessibility$highest_contrast
#> [1] 13.88599
#> 
#> $sport$accessibility$background_luminance
#> [1] 0.6442997
#> 
#> 
#> $sport$ressort
#> [1] "sport"
#> 
#> 
#> $pano
#> $pano$background
#>      pano 
#> "#AFD4AE" 
#> 
#> $pano$contrasts
#> $pano$contrasts$black
#> [1] "#000000"
#> 
#> $pano$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $pano$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $pano$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $pano$contrasts$complementary
#> [1] "#502B51"
#> 
#> $pano$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $pano$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $pano$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $pano$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $pano$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $pano$contrast_ratios
#>              black high_contrast_dark         dark_brown        dark_purple 
#>          12.851384          12.851384           8.458731           7.260991 
#>      complementary          dark_navy           dark_red      dark_charcoal 
#>           7.118060           6.721499           6.086926           5.684791 
#>          dark_blue         dark_green 
#>           5.337006           4.815885 
#> 
#> $pano$recommendations
#> $pano$recommendations$best_overall
#> [1] "black"
#> 
#> $pano$recommendations$best_dark
#> [1] "black"
#> 
#> $pano$recommendations$best_light
#> [1] NA
#> 
#> $pano$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $pano$accessibility
#> $pano$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $pano$accessibility$wcag_aaa_compliant
#> [1] 5
#> 
#> $pano$accessibility$highest_contrast
#> [1] 12.85138
#> 
#> $pano$accessibility$background_luminance
#> [1] 0.5925692
#> 
#> 
#> $pano$ressort
#> [1] "pano"
#> 
#> 
#> $kultur
#> $kultur$background
#>    kultur 
#> "#D2D0CF" 
#> 
#> $kultur$contrasts
#> $kultur$contrasts$black
#> [1] "#000000"
#> 
#> $kultur$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $kultur$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $kultur$contrasts$complementary
#> [1] "#2D2F30"
#> 
#> $kultur$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $kultur$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $kultur$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $kultur$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $kultur$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $kultur$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $kultur$contrast_ratios
#>              black high_contrast_dark         dark_brown      complementary 
#>          13.663676          13.663676           8.993379           8.753920 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           7.719934           7.146343           6.471660           6.044108 
#>          dark_blue         dark_green 
#>           5.674340           5.120280 
#> 
#> $kultur$recommendations
#> $kultur$recommendations$best_overall
#> [1] "black"
#> 
#> $kultur$recommendations$best_dark
#> [1] "black"
#> 
#> $kultur$recommendations$best_light
#> [1] NA
#> 
#> $kultur$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $kultur$accessibility
#> $kultur$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $kultur$accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $kultur$accessibility$highest_contrast
#> [1] 13.66368
#> 
#> $kultur$accessibility$background_luminance
#> [1] 0.6331838
#> 
#> 
#> $kultur$ressort
#> [1] "kultur"
#> 
#> 
#> $etat
#> $etat$background
#>      etat 
#> "#FFCC66" 
#> 
#> $etat$contrasts
#> $etat$contrasts$black
#> [1] "#000000"
#> 
#> $etat$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $etat$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $etat$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $etat$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $etat$contrasts$complementary
#> [1] "#003399"
#> 
#> $etat$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $etat$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $etat$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $etat$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $etat$contrast_ratios
#>              black high_contrast_dark         dark_brown        dark_purple 
#>          14.081008          14.081008           9.268065           7.955725 
#>          dark_navy      complementary           dark_red      dark_charcoal 
#>           7.364614           7.282607           6.669325           6.228714 
#>          dark_blue         dark_green 
#>           5.847652           5.276670 
#> 
#> $etat$recommendations
#> $etat$recommendations$best_overall
#> [1] "black"
#> 
#> $etat$recommendations$best_dark
#> [1] "black"
#> 
#> $etat$recommendations$best_light
#> [1] NA
#> 
#> $etat$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $etat$accessibility
#> $etat$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $etat$accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $etat$accessibility$highest_contrast
#> [1] 14.08101
#> 
#> $etat$accessibility$background_luminance
#> [1] 0.6540504
#> 
#> 
#> $etat$ressort
#> [1] "etat"
#> 
#> 
#> $wiss
#> $wiss$background
#>      wiss 
#> "#BEDAE3" 
#> 
#> $wiss$contrasts
#> $wiss$contrasts$black
#> [1] "#000000"
#> 
#> $wiss$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $wiss$contrasts$complementary
#> [1] "#41251C"
#> 
#> $wiss$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $wiss$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $wiss$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $wiss$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $wiss$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $wiss$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $wiss$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $wiss$contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          14.327202          14.327202           9.512412           9.430108 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           8.094823           7.493378           6.785932           6.337617 
#>          dark_blue         dark_green 
#>           5.949893           5.368928 
#> 
#> $wiss$recommendations
#> $wiss$recommendations$best_overall
#> [1] "black"
#> 
#> $wiss$recommendations$best_dark
#> [1] "black"
#> 
#> $wiss$recommendations$best_light
#> [1] NA
#> 
#> $wiss$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $wiss$accessibility
#> $wiss$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $wiss$accessibility$wcag_aaa_compliant
#> [1] 6
#> 
#> $wiss$accessibility$highest_contrast
#> [1] 14.3272
#> 
#> $wiss$accessibility$background_luminance
#> [1] 0.6663601
#> 
#> 
#> $wiss$ressort
#> [1] "wiss"
#> 
#> 
#> $karriere
#> $karriere$background
#>  karriere 
#> "#F8F8F8" 
#> 
#> $karriere$contrasts
#> $karriere$contrasts$black
#> [1] "#000000"
#> 
#> $karriere$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $karriere$contrasts$complementary
#> [1] "#070707"
#> 
#> $karriere$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $karriere$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $karriere$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $karriere$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $karriere$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $karriere$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $karriere$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $karriere$contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          19.773715          19.773715          18.967705          13.014982 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>          11.172086          10.342000           9.365617           8.746874 
#>          dark_blue         dark_green 
#>           8.211757           7.409936 
#> 
#> $karriere$recommendations
#> $karriere$recommendations$best_overall
#> [1] "black"
#> 
#> $karriere$recommendations$best_dark
#> [1] "black"
#> 
#> $karriere$recommendations$best_light
#> [1] NA
#> 
#> $karriere$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $karriere$accessibility
#> $karriere$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $karriere$accessibility$wcag_aaa_compliant
#> [1] 10
#> 
#> $karriere$accessibility$highest_contrast
#> [1] 19.77371
#> 
#> $karriere$accessibility$background_luminance
#> [1] 0.9386857
#> 
#> 
#> $karriere$ressort
#> [1] "karriere"
#> 
#> 
#> $zukunft
#> $zukunft$background
#>   zukunft 
#> "#E6E6E6" 
#> 
#> $zukunft$contrasts
#> $zukunft$contrasts$black
#> [1] "#000000"
#> 
#> $zukunft$contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $zukunft$contrasts$complementary
#> [1] "#191919"
#> 
#> $zukunft$contrasts$dark_brown
#> [1] "#3E2723"
#> 
#> $zukunft$contrasts$dark_purple
#> [1] "#4A148C"
#> 
#> $zukunft$contrasts$dark_navy
#> [1] "#2C3E50"
#> 
#> $zukunft$contrasts$dark_red
#> [1] "#7B241C"
#> 
#> $zukunft$contrasts$dark_charcoal
#> [1] "#34495E"
#> 
#> $zukunft$contrasts$dark_blue
#> [1] "#1B4F72"
#> 
#> $zukunft$contrasts$dark_green
#> [1] "#1B5E20"
#> 
#> 
#> $zukunft$contrast_ratios
#>              black high_contrast_dark      complementary         dark_brown 
#>          16.825959          16.825959          14.087086          11.074780 
#>        dark_purple          dark_navy           dark_red      dark_charcoal 
#>           9.506613           8.800272           7.969443           7.442939 
#>          dark_blue         dark_green 
#>           6.987593           6.305303 
#> 
#> $zukunft$recommendations
#> $zukunft$recommendations$best_overall
#> [1] "black"
#> 
#> $zukunft$recommendations$best_dark
#> [1] "black"
#> 
#> $zukunft$recommendations$best_light
#> [1] NA
#> 
#> $zukunft$recommendations$complementary
#> [1] "complementary"
#> 
#> 
#> $zukunft$accessibility
#> $zukunft$accessibility$wcag_aa_compliant
#> [1] 10
#> 
#> $zukunft$accessibility$wcag_aaa_compliant
#> [1] 8
#> 
#> $zukunft$accessibility$highest_contrast
#> [1] 16.82596
#> 
#> $zukunft$accessibility$background_luminance
#> [1] 0.7912979
#> 
#> 
#> $zukunft$ressort
#> [1] "zukunft"
#> 
#> 

# Get only dark contrasting colors for sport ressort
find_contrast_color_dst("sport", color_type = "dark")
#> $background
#>     sport 
#> "#C6DC73" 
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
#>     13.885994      9.139707      7.845542      7.262619      6.576959 
#> dark_charcoal     dark_blue    dark_green 
#>      6.142449      5.766666      5.203591 
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
#> [1] 13.88599
#> 
#> $accessibility$background_luminance
#> [1] 0.6442997
#> 
#> 
#> $ressort
#> [1] "sport"
#> 

# Get high contrast options for wirt ressort
find_contrast_color_dst("wirt", contrast_level = "high")
#> $background
#>      wirt 
#> "#D8DEC1" 
#> 
#> $contrasts
#> $contrasts$black
#> [1] "#000000"
#> 
#> $contrasts$high_contrast_dark
#> [1] "#000000"
#> 
#> $contrasts$complementary
#> [1] "#27213E"
#> 
#> 
#> $contrast_ratios
#>              black high_contrast_dark      complementary 
#>           15.13835           15.13835           11.02278 
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
#> [1] 7
#> 
#> $accessibility$highest_contrast
#> [1] 15.13835
#> 
#> $accessibility$background_luminance
#> [1] 0.7069174
#> 
#> 
#> $ressort
#> [1] "wirt"
#> 
```
