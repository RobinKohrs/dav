# Download and Crop NDVI Data from Copernicus CDSE S3

Filters local CSV manifests, finds the correct S3 bucket/key, handles
format switching (COG/NC), and crops the result to an area of interest.

## Usage

``` r
cdse_download_ndvi(
  date_start,
  date_end = NULL,
  collection = "ndvi_global_300m_10daily_v2",
  clipsrc = NULL,
  output_dir = ".",
  format = "cog",
  access_key = NULL,
  secret_key = NULL
)
```

## Arguments

- date_start:

  Date string (YYYY-MM-DD). Start of range or target date.

- date_end:

  Date string (YYYY-MM-DD). Optional. If NULL, finds closest single
  date.

- collection:

  Character. The name of the collection to download. See
  [`cdse_list_ndvi_products()`](https://robinkohrs.github.io/dav/reference/cdse_list_ndvi_products.md)
  for available options. Defaults to "ndvi_global_300m_10daily_v2".

- clipsrc:

  sf object. Area to crop to.

- output_dir:

  Directory to save files.

- format:

  Character. "cog" (Cloud Optimized GeoTIFF) or "nc" (NetCDF). Defaults
  to "cog". Note that some collections only support "nc".

- access_key:

  AWS Access Key ID.

- secret_key:

  AWS Secret Access Key.
