#!/bin/bash

# A script to interactively select shapefiles, clip them to Austria's boundaries, and save as GeoPackage.

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

# --- Configuration ---
AUSTRIA_BOUNDARY_URL="https://geodata.ucdavis.edu/gadm/gadm4.1/json/gadm41_AUT_0.json"
SEARCH_DIR="${1:-.}" # Use first argument as search directory, or default to current directory.

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
    output_file="${outdir}/${base_name}_austria_clipped_${i}.gpkg"

    echo "Clipping '$input_file' and saving to '$output_file'..."

    ogr2ogr \
      -f GPKG \
      -progress \
      "$output_file" \
      "$input_file" \
      -clipsrc "$AUSTRIA_BOUNDARY_URL"

    ((i++))
done

echo
echo "✅ Clipping complete! Output saved in: $outdir"
