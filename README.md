# davR: Data Analysis and Visualization R Package

A comprehensive R package for accessing and analyzing various datasets, with a focus on Palestinian data, Austrian geospatial data, and other humanitarian datasets.

## Overview

The `davR` package provides easy-to-use functions for downloading, processing, and analyzing data from multiple sources including:

- **Palestinian datasets** from TechForPalestine API
- **Austrian geospatial data** from various government sources
- **Humanitarian data** from HDX and other sources
- **Environmental data** including sea ice extent
- **Conflict data** from ACLED

## Installation

```r
# Install from GitHub (if available)
devtools::install_github("your-username/davR")

# Or install locally
devtools::install("path/to/davR")
```

## Palestinian Data Functions

The package includes comprehensive functions for accessing Palestinian data from the [TechForPalestine Palestine Datasets API](https://data.techforpalestine.org/docs/).

### Gaza Data Functions

#### 1. `gaza_killed()` - Individual Names Dataset

**File:** `R/gaza_killed.R`  
**Downloads:** `https://data.techforpalestine.org/api/v3/killed-in-gaza.min.json`

Fetches the complete list of known individuals killed in Gaza with their names, ages, and demographic information.

**Key Features:**

- Multiple download formats: data frame (recommended), CSV, JSON, or page-by-page
- Progress tracking for large downloads
- Automatic data type conversion (dates, ages)
- Handles pagination automatically

**Data Fields:**

- `name`: Original Arabic name
- `en_name`: English name translation
- `id`: Unique identifier
- `dob`: Date of birth
- `sex`: Gender (m/f)
- `age`: Age as number
- `source`: Source indicator (h=Ministry of Health, c=Public Submission, etc.)

**Example:**

```r
# Get complete dataset as data frame (recommended)
killed_df <- gaza_killed()

# Get specific page
page_1 <- gaza_killed(format = "page", page = 1)

# Get as CSV
killed_csv <- gaza_killed(format = "csv")
```

#### 2. `gaza_daily_casualties()` - Daily Casualty Reports

**File:** `R/gaza_daily_gaza.R`  
**Downloads:** `https://data.techforpalestine.org/api/v2/casualties_daily.csv`

Provides time series data of killed and injured counts since October 7th, 2023.

**Data Sources:**

- `mohtel`: Gaza's Ministry of Health Telegram channel (primary)
- `gmotel`: Gaza's Government Media Office Telegram channel
- `unocha`: UN OCHA reports
- `missing`: No official report available

**Key Fields:**

- `report_date`: Date of report
- `killed`: Daily killed count
- `killed_cum`: Cumulative killed
- `killed_children_cum`: Cumulative children killed
- `killed_women_cum`: Cumulative women killed
- `injured`: Daily injured count
- `injured_cum`: Cumulative injured
- `med_killed_cum`: Medical personnel killed
- `press_killed_cum`: Journalists killed
- `famine_cum`: Starvation-related deaths
- `ext_*` fields: Extrapolated values for missing data (see methodology below)

**Extrapolated Fields (ext\_\*):**
Since official numbers weren't always available, extrapolated fields (prefixed with "ext\_") are provided using the following methodology:

- If the missing field was a cumulative one and we had an official report for a daily killed or injury count, we calculate the cumulative using the daily increment
- If the missing field was a daily increment and we had cumulative counts, we subtracted the reported cumulative count from the prior period for the missing daily count
- If we were missing both sets of numbers for a given reporting period we average the difference between surrounding periods

**Important Note:** The Ministry of Health only records direct casualties of war (missile strikes, war-related injuries). They do not include indirect deaths such as:

- Children who die due to malnutrition
- Deaths from lack of medical care
- Underdeveloped infants who die after birth due to poor maternal health
- Other indirect consequences of the conflict

#### 3. `gaza_press_killed()` - Journalists Killed

**File:** `R/gaza_press.R`  
**Downloads:** `https://data.techforpalestine.org/api/v2/press_killed_in_gaza.csv`

Lists journalists and media personnel killed in Gaza.

**Data Fields:**

- `name`: Arabic name
- `name_en`: English name translation
- `notes`: Agency and death details

#### 4. `gaza_infrastructure_damaged()` - Infrastructure Damage

**File:** `R/gaza_infrastructure.R`  
**Downloads:** `https://data.techforpalestine.org/api/v3/infrastructure-damaged.min.json`

Tracks damage to buildings and infrastructure in Gaza.

**Key Categories:**

- Government buildings destroyed
- Educational buildings (destroyed/damaged)
- Places of worship (mosques/churches)
- Residential units destroyed

**Extrapolated Fields (ext\_\*):**
For infrastructure data, extrapolated fields are provided to maintain continuous time series:

- For recent numbers in 2024, these fields display the latest known value for the last received report date
- For earlier reports that were less consistent, incrementing daily values are derived using the difference between two known reporting periods

#### 5. `gaza_west_bank_casualties()` - West Bank Data

**File:** `R/gaza_daily_wb.R`  
**Downloads:** `https://data.techforpalestine.org/api/v2/west_bank_daily.csv`

Daily casualty reports for the West Bank from UN OCHA.

**Data Types:**

- `verified`: Independently verified by UN OCHA
- `flash-updates`: Reported but not yet verified

#### 6. `gaza_summary_data()` - Summary Statistics

**File:** `R/gaza_summary.R`  
**Downloads:** `https://data.techforpalestine.org/api/v3/summary.min.json`

Provides latest cumulative values across all datasets.

**Sections:**

- Gaza: Latest casualty totals
- West Bank: Latest casualty totals
- Known killed in Gaza: Demographic breakdown
- Known press killed: Journalist count

#### 7. `gaza_top_translated_names()` - Name Frequency Data

**File:** `R/gaza_advanced.R`  
**Downloads:** `https://data.techforpalestine.org/api/v2/killed-in-gaza/name-freq-en.json`

Fetches the top 10 translated first names by age group and total counts.

**Data Structure:**

- `lists`: Top 20 names for each category (man, woman, boy, girl)
- `totalUniques`: Number of unique names per category
- `totalPeople`: Total count of people per category

**Examples:**

```r
names_data <- gaza_top_translated_names()
names_data$lists$boy        # Top boys' names
names_data$totalPeople$boy  # Total boys killed: ~10,656
names_data$totalPeople$girl # Total girls killed: ~7,801
```

#### 8. `gaza_commodity_prices()` - Economic Data

**File:** `R/gaza_commodity_prices.R`  
**Downloads:** From HDX (Humanitarian Data Exchange)

Fetches commodity price data for Gaza, with optional German translation.

**Features:**

- Downloads from HDX Excel files
- Processes date columns from Excel serial numbers
- Optional commodity name translation to German
- Returns tidy data format

### West Bank Data Functions

#### `gaza_west_bank_casualties()` - West Bank Casualties

**File:** `R/gaza_daily_wb.R`

Daily casualty reports for the West Bank with verified and unverified data.

## Austrian Data Functions

### Geospatial Data

#### `at_get_austria_poly()` - Austria Boundaries

**File:** `R/at_get_austria_poly.R`

Downloads and processes Austrian administrative boundaries.

#### `at_get_gemeinden()` - Municipal Data

**File:** `R/at_get_gemeinden.R`

Fetches Austrian municipality (Gemeinde) data with geospatial information.

#### `at_capitals_polys()` - Capital Polygons

**File:** `R/at_capitals_polys.R`

Provides polygon data for Austrian state capitals.

### Weather Data

#### `geosphere_get_stations()` - Weather Stations

**File:** `R/geosphere_get_stations.R`

Accesses Austrian weather station data from Geosphere.

#### `geosphere_get_data()` - Weather Data

**File:** `R/geosphere_get_data.R`

Downloads weather data from specific stations.

## Other Data Functions

### Environmental Data

#### `envir_get_sea_ice_extent()` - Sea Ice Data

**File:** `R/envir_get_sea_ice_extent.R`

Fetches sea ice extent data for environmental analysis.

### Conflict Data

#### `acled_download_events()` - ACLED Data

**File:** `R/acled_download_events.R`

Downloads conflict event data from ACLED.

### Humanitarian Data

#### `humdata_download_file()` - HDX Downloads

**File:** `R/humdata_download_file.R`

Generic function for downloading files from Humanitarian Data Exchange.

## Utility Functions

### Data Processing

#### `spatial_create_lookup()` - Spatial Lookup

**File:** `R/spatial_create_lookup.R`

Creates lookup tables for spatial data analysis.

#### `find_cell_in_lookup()` - Cell Lookup

**File:** `R/find_cell_in_lookup.R`

Finds specific cells in lookup tables.

### Visualization

#### `html_create_*()` - HTML Visualizations

**Files:** Multiple HTML creation functions

Creates interactive HTML visualizations including:

- Image sliders and swipers
- Info cards
- Stacked bar charts

### Color Utilities

#### `kjn_colors()` - Color Palettes

**File:** `R/kjn_colors.R`

Provides custom color palettes for visualizations.

#### `nice_colors()` - Nice Color Schemes

**File:** `R/nice_colors.R`

Alternative color schemes for plots.

### System Utilities

#### `sys_get_script_dir()` - Script Directory

**File:** `R/sys_get_script_dir.R`

Gets the directory of the current script.

#### `sys_make_path()` - Path Construction

**File:** `R/sys_make_path.R`

Constructs file paths safely.

## Data Sources

### Primary APIs

- **TechForPalestine API**: `https://data.techforpalestine.org/api/`
- **HDX (Humanitarian Data Exchange)**: `https://data.humdata.org/`
- **ACLED API**: For conflict data
- **Geosphere API**: For Austrian weather data

### Data Updates

- Palestinian data is updated regularly by TechForPalestine
- Austrian data follows government update schedules
- Environmental data varies by source

## Dependencies

### Required Packages

- `httr`: HTTP requests
- `jsonlite`: JSON parsing
- `readr`: CSV reading
- `dplyr`: Data manipulation
- `sf`: Spatial data handling
- `terra`: Raster data processing

### Suggested Packages

- `ggplot2`: Plotting
- `DT`: Interactive tables
- `polyglotr`: Translation services (for commodity prices)

## Helper Scripts

The package includes various helper scripts in the `helper_scripts/` directory:

### Project Management

- `dav_create_data_project.sh`: Creates new data analysis projects
- `dav_project_manager.sh`: Manages project workflows

### Content Creation

- `dav_add_dataset.sh`: Adds new datasets
- `dav_create_quiz_html.sh`: Creates quiz HTML files
- `dav_makeQuartoDir.sh`: Sets up Quarto directories

### File Management

- `dav_convert_images_to_webp.sh`: Converts images to WebP format
- `dav_list_and_remove_biggest_files.sh`: Manages large files

### Git Utilities

- `dav_gitignore_large_files.sh`: Manages .gitignore for large files
- `dav_smart_git_add.sh`: Smart git add functionality

## Examples

### Basic Usage

```r
# Load the package
library(davR)

# Get summary statistics
summary_data <- gaza_summary_data()
print(summary_data$gaza$killed$total)

# Get individual names (this downloads the killed-in-gaza.min.json)
killed_data <- gaza_killed()
head(killed_data)

# Get daily casualties
daily_data <- gaza_daily_casualties()
plot(daily_data$report_date, daily_data$killed_cum, type = "l")

# Get commodity prices
prices <- gaza_commodity_prices()
```

### Advanced Analysis

```r
# Get infrastructure damage over time
infrastructure <- gaza_infrastructure_damaged()
plot(infrastructure$report_date, infrastructure$residential.destroyed, type = "l")

# Get Austrian weather data
stations <- geosphere_get_stations()
weather_data <- geosphere_get_data(station_id = "some_station_id")
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- TechForPalestine for maintaining the Palestinian datasets API
- Austrian government agencies for geospatial data
- HDX for humanitarian data access
- All contributors to the open data movement

## Support

For issues and questions:

1. Check the documentation
2. Search existing issues
3. Create a new issue with detailed information

## Changelog

See the package NEWS file for version history and updates.
