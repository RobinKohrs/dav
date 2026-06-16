# Create opposing LAEA projections and clipping masks for world maps

This function generates two opposing Lambert Azimuthal Equal-Area (LAEA)
projections and corresponding clipping masks. This is useful for
creating global maps for mobile devices, where two hemispheres are
stacked to optimize screen space and reduce distortion.

This function generates two opposing Lambert Azimuthal Equal-Area (LAEA)
projections and corresponding clipping masks. This is useful for
creating global maps for mobile devices, where two hemispheres are
stacked to optimize screen space and reduce distortion.

## Usage

``` r
geo_create_clipped_laea(lon, lat)

geo_create_clipped_laea(lon, lat)
```

## Arguments

- lon:

  A numeric value specifying the longitude for the center of the "front"
  hemisphere.

- lat:

  A numeric value specifying the latitude for the center of the "front"
  hemisphere.

## Value

A list containing the following elements:

- `front_proj`:

  The proj4string for the front hemisphere.

- `back_proj`:

  The proj4string for the back (antipodal) hemisphere.

- `front_clip`:

  An 'sf' polygon object for clipping the front hemisphere.

- `back_clip`:

  An 'sf' polygon object for clipping the back hemisphere.

A list containing the following elements:

- `front_proj`:

  The proj4string for the front hemisphere.

- `back_proj`:

  The proj4string for the back (antipodal) hemisphere.

- `front_clip`:

  An 'sf' polygon object for clipping the front hemisphere.

- `back_clip`:

  An 'sf' polygon object for clipping the back hemisphere.

## Examples

``` r
if (FALSE) { # \dontrun{
if (requireNamespace("sf", quietly = TRUE)) {
  projections <- geo_create_clipped_laea(lon = 10, lat = 50)
  print(projections$front_proj)
  print(projections$back_proj)
  # To see the clipping polygon
  # plot(projections$front_clip)
}
} # }
if (FALSE) { # \dontrun{
if (requireNamespace("sf", quietly = TRUE)) {
  projections <- geo_create_clipped_laea(lon = 10, lat = 50)
  print(projections$front_proj)
  print(projections$back_proj)
  # To see the clipping polygon
  # plot(projections$front_clip)

  # Greenland example
  greenland_proj <- geo_create_clipped_laea(lon = -40, lat = 72)
}
} # }
```
