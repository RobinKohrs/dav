# Get Best Contrasting Color for DST Ressort

Quick helper function to get the single best contrasting color for a DST
ressort.

## Usage

``` r
get_best_dst_contrast(ressort, contrast_level = "AA", color_type = "all")
```

## Arguments

- ressort:

  Character. Name of the ressort.

- contrast_level:

  Character. Desired contrast level.

- color_type:

  Character. Type of contrasting color.

## Value

Character. Hex color code of the best contrasting color.

## Examples

``` r
# Get best contrasting color for apo
get_best_dst_contrast("apo")
#> $black
#> [1] "#000000"
#> 

# Get best dark contrasting color for sport
get_best_dst_contrast("sport", color_type = "dark")
#> $black
#> [1] "#000000"
#> 
```
