#!/bin/bash

# ---
# Converts images to WebP format with interactive folder and file selection.
# Dependencies: gum, fzf, cwebp
# ---

# Function to display help
show_help() {
    gum style \
	--foreground 212 --border double --margin "1" --padding "1" \
	"Image to WebP Converter" \
	"This script converts images to WebP format.
You will be asked to select:
1. An input directory.
2. A file extension (e.g., png, jpg) or a single file.
3. An output directory (a default will be suggested)."
}

# Show help section
show_help

# 1. Select input directory
gum style --bold "Select the input directory:"
INPUT_DIR=$(find . -type d | fzf)
[[ -z "$INPUT_DIR" ]] && echo "No directory selected. Exiting." && exit 1

# 2. Choose to convert all files of a certain type or a single file
CONVERSION_MODE=$(gum choose "All files with a specific extension" "A single file")

if [[ "$CONVERSION_MODE" == "A single file" ]]; then
    # Select a single file
    gum style --bold "Select an image file:"
    FILE_TO_CONVERT=$(find "$INPUT_DIR" -type f | fzf)
    [[ -z "$FILE_TO_CONVERT" ]] && echo "No file selected. Exiting." && exit 1
    files_to_convert=("$FILE_TO_CONVERT")
else
    # Select extension
    gum style --bold "Select the file extension of images to convert (e.g., png, jpg):"
    EXT=$(gum input --placeholder "jpg")
    [[ -z "$EXT" ]] && echo "No extension provided. Exiting." && exit 1
    files_to_convert=("$INPUT_DIR"/*."$EXT")
fi

# Check if any files were found
if [ ${#files_to_convert[@]} -eq 0 ]; then
    echo "No files found to convert."
    exit 0
fi

# 3. Select output directory
DEFAULT_OUTPUT_DIR="$INPUT_DIR/webp"
gum style --bold "Enter the output directory:"
OUTPUT_DIR=$(gum input --value "$DEFAULT_OUTPUT_DIR")
mkdir -p "$OUTPUT_DIR"

# 3.5. Select image quality
DEFAULT_QUALITY=80
gum style --bold "Enter image quality (0-100, default: $DEFAULT_QUALITY):"
QUALITY=$(gum input --value "$DEFAULT_QUALITY")
if [[ -z "$QUALITY" ]]; then
    QUALITY=$DEFAULT_QUALITY
fi

# 4. Convert images
for file in "${files_to_convert[@]}"; do
    if [ -f "$file" ]; then
        filename=$(basename -- "$file")
        filename_no_ext="${filename%.*}"
        output_path="$OUTPUT_DIR/$filename_no_ext.webp"
        
        echo "Converting $file to $output_path with quality $QUALITY"
        cwebp -q "$QUALITY" "$file" -o "$output_path"
    fi
done

gum style \
	--foreground "#04B575" --border double --margin "1" --padding "1" \
	"Conversion Complete!" \
	"All selected images have been converted to WebP format and saved in '$OUTPUT_DIR'." 