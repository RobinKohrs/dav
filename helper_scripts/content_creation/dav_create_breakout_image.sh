#!/bin/bash

# 1. Prompt for inputs
echo "--- HTML Picture Generator ---"
read -p "Enter path/URL for DESKTOP image: " desktop_img
read -p "Enter path/URL for MOBILE image: " mobile_img
read -p "Enter Alt Text description: " alt_text
read -p "Enter Image Height (default: auto): " img_height
img_height=${img_height:-auto}
read -p "Enter object-fit mode (cover/contain, default: contain): " obj_fit
obj_fit=${obj_fit:-contain}
read -p "Enter breakout shift amount (default: 42.5px): " breakout_shift
breakout_shift=${breakout_shift:-42.5px}
read -p "Enter output filename (leave empty to copy to clipboard): " output_file

# 2. Construct the HTML content using a Here-Doc
# Generate a unique class name to prevent collisions
# Use openssl if available for a random hex string, otherwise fallback to random number
if command -v openssl &> /dev/null; then
    rand_hash=$(openssl rand -hex 4)
else
    rand_hash="$RANDOM$RANDOM"
fi
unique_class="dj-$rand_hash"

html_content="<style>
.$unique_class {
  display: block;
  width: 100%;
}

.$unique_class img {
  display: block;
  width: 100%;
  height: $img_height;
  object-fit: $obj_fit;
  object-position: center;
  border-radius: 4px;
}

/* Styles for desktop screens (768px and wider) */
@media (min-width: 768px) {
  .$unique_class {
    /* Apply the \"breakout\" effect to the picture container */
    width: calc(100% + (2 * $breakout_shift));
    transform: translateX(-$breakout_shift);
  }
}
</style>

<picture class=\"$unique_class\">
  <source media=\"(min-width: 768px)\" srcset=\"$desktop_img\">
  <source media=\"(max-width: 767px)\" srcset=\"$mobile_img\">
  <img src=\"$desktop_img\" alt=\"$alt_text\">
</picture>"

# 3. Handle Output (File vs Clipboard)
if [ -n "$output_file" ]; then
    # If output_file is NOT empty (-n), write to file
    echo "$html_content" > "$output_file"
    echo "--------------------------------"
    echo "✅ Success! Saved HTML to: $output_file"
else
    # If output_file IS empty, try to copy to clipboard
    
    # Check for macOS
    if command -v pbcopy &> /dev/null; then
        echo "$html_content" | pbcopy
        echo "✅ Copied to clipboard (macOS)."
    
    # Check for Linux (Wayland)
    elif command -v wl-copy &> /dev/null; then
        echo "$html_content" | wl-copy
        echo "✅ Copied to clipboard (Wayland)."

    # Check for Linux (X11 - xclip)
    elif command -v xclip &> /dev/null; then
        echo "$html_content" | xclip -selection clipboard
        echo "✅ Copied to clipboard (xclip)."
        
    # Check for Linux (X11 - xsel)
    elif command -v xsel &> /dev/null; then
        echo "$html_content" | xsel --clipboard --input
        echo "✅ Copied to clipboard (xsel)."

    # Check for Windows WSL (Windows Subsystem for Linux)
    elif command -v clip.exe &> /dev/null; then
        echo "$html_content" | clip.exe
        echo "✅ Copied to clipboard (Windows WSL)."
        
    else
        echo "⚠️  Could not detect a clipboard utility."
        echo "Here is the code:"
        echo "--------------------------------"
        echo "$html_content"
        echo "--------------------------------"
    fi
fi