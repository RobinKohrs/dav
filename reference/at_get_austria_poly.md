# Get Austria Boundary Shape at Specified Resolution

Retrieves the administrative boundary of Austria as an sf object, using
pre-packaged data derived from Eurostat/GISCO.

## Usage

``` r
at_get_austria_poly(resolution = "10")
```

## Arguments

- resolution:

  Character string. The desired resolution code. Available options
  packaged are: "60" (1:60 Million) (low), "10" (1:10 milltion)
  (medium), "01" (1:1 Million) (high). Defaults to "10".

## Value

An [`sf`](https://r-spatial.github.io/sf/reference/sf.html) object
representing the boundary of Austria at the specified resolution.
Includes columns for name, ISO2 code, and geometry.

## Details

The data is included within the package. Available resolutions
correspond to the GISCO distribution codes. See
<https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units/countries>

## Examples

``` r
if (FALSE)  # Requires sf package to be fully functional
  if (requireNamespace("sf", quietly = TRUE)) {
    # Get default resolution (10)
    aut_shape_med = get_austria_shape()
    plot(sf::st_geometry(aut_shape_med), main = "Austria (10M)")

    # Get high resolution
    aut_shape_high = get_austria_shape(resolution = "01")
    plot(sf::st_geometry(aut_shape_high), main = "Austria (01)", border = "blue")

    # Get low resolution
    aut_shape_low = get_austria_shape(resolution = "60")
    plot(sf::st_geometry(aut_shape_low), main = "Austria (60)", border = "red")
  }
 # \dontrun{}
```
