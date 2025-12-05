# Define the lookup table for NDVI products
.cdse_ndvi_products <- function() {
  base_url <- "https://s3.waw3-1.cloudferro.com/swift/v1/CatalogueCSV/bio-geophysical/vegetation_indices"

  dplyr::tribble(
    ~collection                      , ~resolution , ~version , ~type                    , ~format_avail , ~validity                 , ~csv_url                                                                                  ,
    "ndvi_global_300m_10daily_v2"    , "300m"      , "v2"     , "10-daily"               , "cog/nc"      , "2020-07-01 - present"    , paste0(base_url, "/ndvi_global_300m_10daily_v2/ndvi_global_300m_10daily_v2_cog.csv")      ,
    "ndvi_global_300m_10daily_v1"    , "300m"      , "v1"     , "10-daily"               , "nc"          , "2014-01-01 - 2021-01-01" , paste0(base_url, "/ndvi_global_300m_10daily_v1/ndvi_global_300m_10daily_v1_nc.csv")       ,
    "ndvi_global_1km_10daily_v3"     , "1km"       , "v3"     , "10-daily"               , "nc"          , "1999-01-01 - 2020-06-21" , paste0(base_url, "/ndvi_global_1km_10daily_v3/ndvi_global_1km_10daily_v3_nc.csv")         ,
    "ndvi_global_1km_10daily_v2"     , "1km"       , "v2"     , "10-daily"               , "nc"          , "1998-04-01 - 2020-12-21" , paste0(base_url, "/ndvi_global_1km_10daily_v2/ndvi_global_1km_10daily_v2_nc.csv")         ,
    "ndvi-lts_global_1km_10daily_v3" , "1km"       , "v3"     , "LTS (Long Term Stats)"  , "nc"          , "1999 - 2019"             , paste0(base_url, "/ndvi-lts_global_1km_10daily_v3/ndvi-lts_global_1km_10daily_v3_nc.csv") ,
    "ndvi-lts_global_1km_10daily_v2" , "1km"       , "v2"     , "LTS (Long Term Stats)"  , "nc"          , "1999 - 2017"             , paste0(base_url, "/ndvi-lts_global_1km_10daily_v2/ndvi-lts_global_1km_10daily_v2_nc.csv") ,
    "ndvi-sts_global_1km_10daily_v3" , "1km"       , "v3"     , "STS (Short Term Stats)" , "nc"          , "2015 - 2019"             , paste0(base_url, "/ndvi-sts_global_1km_10daily_v3/ndvi-sts_global_1km_10daily_v3_nc.csv")
  )
}

#' List Available Copernicus NDVI Products
#'
#' Displays a table of available NDVI products from the Copernicus Data Space Ecosystem,
#' including resolution, version, and available formats.
#'
#' @return A data frame (tibble) containing product details.
#' @export
cdse_list_ndvi_products <- function() {
  .cdse_ndvi_products() %>%
    dplyr::select(
      collection,
      resolution,
      version,
      type,
      validity,
      format_avail,
      csv_url
    )
}

#' Download and Crop NDVI Data from Copernicus CDSE S3
#'
#' Filters local CSV manifests, finds the correct S3 bucket/key, handles
#' format switching (COG/NC), and crops the result to an area of interest.
#'
#' @param date_start Date string (YYYY-MM-DD). Start of range or target date.
#' @param date_end Date string (YYYY-MM-DD). Optional. If NULL, finds closest single date.
#' @param collection Character. The name of the collection to download.
#'   See \code{cdse_list_ndvi_products()} for available options.
#'   Defaults to "ndvi_global_300m_10daily_v2".
#' @param clipsrc sf object. Area to crop to.
#' @param output_dir Directory to save files.
#' @param format Character. "cog" (Cloud Optimized GeoTIFF) or "nc" (NetCDF).
#'   Defaults to "cog". Note that some collections only support "nc".
#' @param access_key AWS Access Key ID.
#' @param secret_key AWS Secret Access Key.
#' @export
cdse_download_ndvi <- function(
  date_start,
  date_end = NULL,
  collection = "ndvi_global_300m_10daily_v2",
  clipsrc = NULL,
  output_dir = ".",
  format = "cog",
  access_key = NULL,
  secret_key = NULL
) {
  # --- 1. Setup and Dependencies ---

  if (!format %in% c("cog", "nc")) {
    stop("format must be 'cog' or 'nc'")
  }

  # Resolve Collection to CSV URL
  products <- .cdse_ndvi_products()
  if (!collection %in% products$collection) {
    stop(
      "Invalid collection. Run `cdse_list_ndvi_products()` to see available options."
    )
  }

  prod_info <- products[products$collection == collection, ]
  csv_resources <- prod_info$csv_url

  # Check if requested format is likely supported (soft check)
  if (format == "cog" && !grepl("cog", prod_info$format_avail)) {
    warning(paste(
      "Collection",
      collection,
      "mostly contains NetCDF (.nc). 'cog' format might not be available."
    ))
  }

  # Set credentials for session
  if (!is.null(access_key)) {
    Sys.setenv("AWS_ACCESS_KEY_ID" = access_key)
  }
  if (!is.null(secret_key)) {
    Sys.setenv("AWS_SECRET_ACCESS_KEY" = secret_key)
  }

  # CDSE Endpoint Constant
  S3_ENDPOINT <- "eodata.dataspace.copernicus.eu"

  message(paste("--- Accessing Catalog:", collection, "---"))

  # --- 2. Read CSVs ---

  full_catalog <- tryCatch(
    {
      dplyr::bind_rows(lapply(csv_resources, function(x) {
        # read_delim handles URLs automatically
        readr::read_delim(x, delim = ";", show_col_types = FALSE)
      }))
    },
    error = function(e) stop("Failed reading catalog CSV: ", e$message)
  )

  if (nrow(full_catalog) == 0) {
    stop("No data found in catalog.")
  }

  # Normalize columns
  names(full_catalog) <- tolower(names(full_catalog))

  # Find date column
  if (!"nominal_date" %in% names(full_catalog)) {
    date_col <- names(full_catalog)[grepl("date|time", names(full_catalog))][1]
    if (is.na(date_col)) {
      stop("No date column found in CSV")
    }
    full_catalog$nominal_date <- full_catalog[[date_col]]
  }

  if (!"s3_path" %in% names(full_catalog)) {
    stop("No 's3_path' column in CSV")
  }

  # Filter Data
  catalog_clean <- full_catalog %>%
    dplyr::mutate(
      parsed_date = lubridate::as_date(nominal_date),
      s3_path = as.character(s3_path)
    ) %>%
    dplyr::filter(!is.na(parsed_date))

  date_start <- lubridate::as_date(date_start)

  # --- 3. Date Selection Logic ---

  if (is.null(date_end)) {
    message(paste("Searching closest image to", date_start))
    idx <- which.min(abs(catalog_clean$parsed_date - date_start))
    target_files <- catalog_clean[idx, , drop = FALSE]
    message(paste("Selected date:", target_files$parsed_date))
  } else {
    date_end <- lubridate::as_date(date_end)
    message(paste("Searching range", date_start, "to", date_end))
    target_files <- catalog_clean %>%
      dplyr::filter(parsed_date >= date_start & parsed_date <= date_end)
    message(paste("Found", nrow(target_files), "images."))
  }

  if (nrow(target_files) == 0) {
    return(invisible(NULL))
  }

  # Ensure output directory exists
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  processed_files <- c()

  # --- 4. Main Processing Loop ---

  for (i in 1:nrow(target_files)) {
    row <- target_files[i, ]
    s3_raw_path <- row$s3_path

    # A. Parse Bucket/Prefix
    parts <- strsplit(s3_raw_path, "/")[[1]]

    # FORCE bucket to lowercase 'eodata' (Crucial for CDSE)
    bucket_name <- "eodata"

    # Extract the directory prefix from CSV
    # Usually parts: "s3:", "", "EODATA", "CLMS", ...
    folder_prefix <- paste(parts[4:length(parts)], collapse = "/")

    # B. Smart Path Adjustment (Swap _cog/_nc based on request)
    # This logic mainly applies to the 300m v2 collection which has dual formats side-by-side
    if (format == "nc" && grepl("_cog$", folder_prefix)) {
      folder_prefix <- sub("_cog$", "_nc", folder_prefix)
    } else if (format == "cog" && grepl("_nc$", folder_prefix)) {
      folder_prefix <- sub("_nc$", "_cog", folder_prefix)
    }

    message(paste0(
      "[",
      i,
      "/",
      nrow(target_files),
      "] Checking folder: ",
      folder_prefix
    ))

    # C. List Objects to find the specific file
    tryCatch(
      {
        items <- aws.s3::get_bucket(
          bucket = bucket_name,
          prefix = folder_prefix,
          base_url = S3_ENDPOINT,
          region = "",
          use_https = TRUE,
          check_region = FALSE,
          path_style = TRUE
        )

        keys <- sapply(items, function(x) x$Key)

        # D. Filter for the specific file type
        target_key <- NULL

        if (format == "cog") {
          # Look for .tiff AND "NDVI" (to skip quality flags)
          # Use regex: contains "NDVI" (case insensitive) and ends in .tif/.tiff
          matches <- keys[grepl(
            "NDVI.*\\.tiff?$|NDVI.*\\.tif$",
            keys,
            ignore.case = TRUE
          )]
          if (length(matches) > 0) target_key <- matches[1]
        } else if (format == "nc") {
          # Look for .nc
          matches <- keys[grepl("\\.nc$", keys, ignore.case = TRUE)]
          if (length(matches) > 0) target_key <- matches[1]
        }

        if (is.null(target_key)) {
          message("  -> Warning: Target format not found in folder. Skipping.")
          next
        }

        message(paste("  -> Found:", basename(target_key)))

        # E. Download
        original_filename <- basename(target_key)
        temp_file <- file.path(
          output_dir,
          paste0("temp_", Sys.getpid(), "_", original_filename)
        )

        aws.s3::save_object(
          object = target_key,
          bucket = bucket_name,
          file = temp_file,
          base_url = S3_ENDPOINT,
          region = "",
          use_https = TRUE,
          path_style = TRUE,
          check_region = FALSE
        )

        # F. Crop/Mask
        r <- terra::rast(temp_file)

        if (!is.null(clipsrc)) {
          clip_vect <- terra::vect(clipsrc)
          # Project clipsrc to raster CRS if needed
          if (terra::crs(r) != terra::crs(clip_vect)) {
            clip_vect <- terra::project(clip_vect, terra::crs(r))
          }
          r_cropped <- terra::crop(r, clip_vect)
          r_final <- terra::mask(r_cropped, clip_vect)
        } else {
          r_final <- r
        }

        # G. Save Final
        # Handle extension for output
        ext <- if (format == "nc") ".nc" else ".tif"
        final_name <- paste0(
          tools::file_path_sans_ext(original_filename),
          "_clipped",
          ext
        )
        final_path <- file.path(output_dir, final_name)

        terra::writeRaster(
          r_final,
          final_path,
          overwrite = TRUE,
          gdal = c("COMPRESS=LZW", "PREDICTOR=2")
        )

        processed_files <- c(processed_files, final_path)
        message(paste("  -> Saved:", final_path))

        # H. Cleanup
        rm(r, r_final)
        if (exists("r_cropped")) {
          rm(r_cropped)
        }
        gc()
        unlink(temp_file)
      },
      error = function(e) {
        message(paste("  -> Error:", e$message))
        if (exists("temp_file") && file.exists(temp_file)) unlink(temp_file)
      }
    )
  }

  message("Done.")
  return(invisible(processed_files))
}
