# Geosphere API

``` r
library(davR)
library(DT)
library(readr)
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
```

## Get the available datasets

``` r
ds = geosphere_get_datasets()
DT::datatable(ds)
```
