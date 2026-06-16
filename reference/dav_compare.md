# Compare multiple vectors

This function takes multiple vectors as input and returns a data frame
showing the presence or absence of each unique element across all
vectors.

## Usage

``` r
dav_compare(...)
```

## Arguments

- ...:

  A variable number of vectors to compare.

## Value

A data frame with a column 'element' containing all unique elements from
the input vectors. For each input vector, a logical column 'in_vector_i'
is added, indicating if the element is present in that vector. An
additional column 'in_all' is TRUE if the element is present in all
vectors.

## Examples

``` r
vec1 <- c("a", "b", "c")
vec2 <- c("b", "c", "d")
vec3 <- c("c", "d", "e")
dav_compare(vec1, vec2, vec3)
#>   element in_vector_1 in_vector_2 in_vector_3 in_all
#> 1       a        TRUE       FALSE       FALSE  FALSE
#> 2       b        TRUE        TRUE       FALSE  FALSE
#> 3       c        TRUE        TRUE        TRUE   TRUE
#> 4       d       FALSE        TRUE        TRUE  FALSE
#> 5       e       FALSE       FALSE        TRUE  FALSE
```
