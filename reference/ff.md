# Create a Customized Data Frame Search Function

This function acts as a factory, returning another function that is
tailored to search within a specific data frame (or sf object). The
returned search function can perform case-insensitive regular expression
searches or fuzzy string matching.

## Usage

``` r
ff(df, default_cols = NULL)
```

## Arguments

- df:

  A data.frame or an sf object to be searched.

- default_cols:

  An optional character vector of column names to be used as the default
  set for searching by the returned function. If `NULL` (the default),
  and no columns are specified in a call to the returned search
  function, all character and factor columns of `df` will be searched.
  For `sf` objects, the geometry column is automatically excluded from
  this default. If specified columns are not character or factor, they
  will be coerced to character for searching, with a warning when the
  search function is used.

## Value

A new function with the following signature:
`function(pattern, fuzzy = FALSE, top_n = 3, fuzzy_method = "osa", cols = NULL)`

- `pattern`:

  A character string (regex or plain text for fuzzy) to search for.

- `fuzzy`:

  Logical. If `TRUE`, performs fuzzy matching using the `stringdist`
  package to find the `top_n` most similar rows. Defaults to `FALSE`
  (regex search). The `stringdist` package must be installed and will be
  imported by this package.

- `top_n`:

  Integer. If `fuzzy = TRUE`, the number of best matches to return.
  Defaults to 3.

- `fuzzy_method`:

  Character. The method for `stringdist` calculation if `fuzzy = TRUE`.
  Defaults to "osa" (Optimal String Alignment). See
  `?stringdist::stringdistmethods` for other options.

- `cols`:

  An optional character vector of column names to search within for
  *this specific call*. If provided, this overrides any `default_cols`
  set when `ff` was called. If `NULL` (the default), the search will use
  the `default_cols` (if provided to `ff`) or all character/factor
  columns if no `default_cols` were set.

This returned function will take a `pattern` and search the data frame
originally passed to `ff`, returning the matching rows.

## Examples

``` r
# Create a sample data frame
my_data = data.frame(
  ID = 1:5,
  Name = c("Apple Pie", "Banana Bread", "Cherry Cake", "Date Squares", "Elderflower Tea"),
  Category = factor(c("Dessert", "Baked Good", "Dessert", "Snack", "Beverage")),
  Description = c("Sweet apple filling", "Moist banana loaf",
                  "Rich cherry flavor", "Chewy dates", "Refreshing floral drink"),
  stringsAsFactors = FALSE
)

# 1. Searcher with no default columns (will search all char/factor cols by default)
search_all_defaults = ff(my_data)
search_all_defaults("apple") # Searches Name, Category, Description
#>   ID      Name Category         Description
#> 1  1 Apple Pie  Dessert Sweet apple filling
search_all_defaults("apple", cols = "Name") # Overrides to search only Name
#>   ID      Name Category         Description
#> 1  1 Apple Pie  Dessert Sweet apple filling
search_all_defaults("Dessert", cols = c("Name", "Category")) # Searches specified
#>   ID        Name Category         Description
#> 1  1   Apple Pie  Dessert Sweet apple filling
#> 3  3 Cherry Cake  Dessert  Rich cherry flavor

# 2. Searcher with default columns specified
search_name_default = ff(my_data, default_cols = "Name")
search_name_default("apple") # Searches only Name (default)
#>   ID      Name Category         Description
#> 1  1 Apple Pie  Dessert Sweet apple filling
search_name_default("Dessert") # Searches only Name (default), won't find
#> [1] ID          Name        Category    Description
#> <0 rows> (or 0-length row.names)
search_name_default("Dessert", cols = "Category") # Overrides to search Category
#>   ID        Name Category         Description
#> 1  1   Apple Pie  Dessert Sweet apple filling
#> 3  3 Cherry Cake  Dessert  Rich cherry flavor
search_name_default("Bread", cols = c("Name", "Description")) # Override
#>   ID         Name   Category       Description
#> 2  2 Banana Bread Baked Good Moist banana loaf

# 3. Searcher with multiple default columns
search_name_cat_default = ff(my_data, default_cols = c("Name", "Category"))
search_name_cat_default("apple") # Searches Name and Category
#>   ID      Name Category         Description
#> 1  1 Apple Pie  Dessert Sweet apple filling
search_name_cat_default("Baked") # Finds in Category
#>   ID         Name   Category       Description
#> 2  2 Banana Bread Baked Good Moist banana loaf
search_name_cat_default("filling", cols = "Description") # Overrides
#>   ID      Name Category         Description
#> 1  1 Apple Pie  Dessert Sweet apple filling

# Fuzzy search with override
search_all_defaults("Banna Bred", fuzzy = TRUE, top_n = 1) # Uses default cols
#>   ID         Name Category Description
#> 4  4 Date Squares    Snack Chewy dates
search_all_defaults("Banna Bred", fuzzy = TRUE, top_n = 1, cols="Name") # Uses override
#>   ID         Name   Category       Description
#> 2  2 Banana Bread Baked Good Moist banana loaf

# Error if default_cols in ff don't exist
# try(ff(my_data, default_cols = "NonExistentCol"))

# Error if cols in searcher don't exist
# try(search_all_defaults("test", cols = "NonExistentCol"))
```
