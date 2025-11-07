#!/bin/bash

# A script to interactively select shapefiles, clip them to a country's boundaries, and save as GeoPackage.

set -e # Exit immediately if a command exits with a non-zero status.

# Make zsh arrays 0-indexed like bash to ensure compatibility
if [ -n "$ZSH_VERSION" ]; then
    setopt KSH_ARRAYS
fi

# --- Dependency Check ---
if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install it to use this script (https://github.com/junegunn/fzf)." >&2
    exit 1
fi

if ! command -v gum &> /dev/null; then
    echo "Error: gum is not installed. Please install it to use this script (https://github.com/charmbracelet/gum)." >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it to use this script (https://stedolan.github.io/jq/)." >&2
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it to use this script." >&2
    exit 1
fi


# --- Configuration ---
SEARCH_DIR="${1:-.}" # Use first argument as search directory, or default to current directory.

# --- Country Selection ---
echo "Fetching country data..."
# Fetch country data and format for fzf: "Country Name (ABC)"
country_data=$(curl -s "https://restcountries.com/v3.1/all?fields=name,cca3")

if [ -z "$country_data" ]; then
    echo "Error: Failed to fetch country data. Please check your internet connection." >&2
    exit 1
fi

country_list=$(echo "$country_data" | jq -r '.[] | .name.common + " (" + .cca3 + ")"' | sort)

if [ -z "$country_list" ]; then
    echo "Error: Failed to parse country data. 'jq' might not be working correctly." >&2
    exit 1
fi

selected_country_str=$(echo "$country_list" | fzf --prompt="Select a country to clip shapefiles to > " --height=40% --border)

if [ -z "$selected_country_str" ]; then
    echo "No country selected. Exiting."
    exit 0
fi

# Extract country code from "Country Name (ABC)"
country_code=$(echo "$selected_country_str" | sed -n 's/.*(\(...\)).*/\1/p')
country_name_for_filename=$(echo "$selected_country_str" | sed -n 's/\(.*\)\s(.*)/\1/p' | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

if [ -z "$country_code" ]; then
    echo "Error: Could not extract country code from selection." >&2
    exit 1
fi

COUNTRY_BOUNDARY_URL="https://geodata.ucdavis.edu/gadm/gadm4.1/json/gadm41_${country_code}_0.json"


# --- Main Logic ---

# 0. Check if search directory exists
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory '$SEARCH_DIR' not found."
    echo "Usage: $0 [search_directory]"
    exit 1
fi

# 1. Find shapefiles
echo "Searching for shapefiles (*.shp) in '$SEARCH_DIR' and subdirectories..."
# Use find and store in an array. Using -print0 and read -d '' is safer for filenames with spaces.
files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find "$SEARCH_DIR" -type f -name "*.shp" -print0)

if [ ${#files[@]} -eq 0 ]; then
    echo "No shapefiles found in '$SEARCH_DIR'. Exiting."
    exit 0
fi

# 2. Interactive file selection with fzf
# Use fzf for multi-selection. The result is a string with newlines.
selected_files_str=$(printf "%s\n" "${files[@]}" | fzf --multi --prompt="Select shapefiles to clip (use space/tab to select) > " --height=40% --border --bind "space:toggle,tab:toggle")

if [ -z "$selected_files_str" ]; then
    echo "No files selected. Exiting."
    exit 0
fi

# Convert the newline-separated string into an array using a portable while-read loop
selected_files=()
while IFS= read -r line; do
    # Add to array, ignoring empty lines which can happen
    if [ -n "$line" ]; then
        selected_files+=("$line")
    fi
done <<< "$selected_files_str"

# 3. Get output directory name with gum
outdir=$(gum input --prompt "Enter a name for the output directory: " --placeholder "clipped_shapefiles")

if [ -z "$outdir" ]; then
    echo "No output directory name provided. Exiting."
    exit 1
fi

mkdir -p "$outdir"

# 4. Process selected files
echo
echo "Processing selected files..."

let i=1
for input_file in "${selected_files[@]}"; do
    # Generate a clean output filename.
    base_name=$(basename "$input_file" .shp)
    output_file="${outdir}/${base_name}_${country_name_for_filename}_clipped_${i}.gpkg"

    echo "Clipping '$input_file' and saving to '$output_file'..."

    ogr2ogr \
      -f GPKG \
      -progress \
      "$output_file" \
      "$input_file" \
      -clipsrc "$COUNTRY_BOUNDARY_URL"

    ((i++))
done

echo
echo "✅ Clipping complete! Output saved in: $outdir"
