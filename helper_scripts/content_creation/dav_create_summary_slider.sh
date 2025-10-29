#!/bin/bash
# dav_create_summary_slider.sh
#
# Creates an HTML file with an interactive summary slider component.
# This script will prompt the user for the necessary content.

set -euo pipefail

# --- Functions ---

# Function to display usage information
usage() {
    echo "Usage: $0 \"Title Left\" \"Item 1|Item 2\" \"Title Right\" \"Fact 1|Fact 2\" \"output.html\""
    echo "  - Creates an HTML file with an interactive summary slider."
    exit 1
}

# Function to generate list items from a pipe-separated string
generate_list_items() {
    local items_str=$1
    IFS='|' read -ra items <<< "$items_str"
    for item in "${items[@]}"; do
        echo "              <li class=\"generated\">${item}</li>"
    done
}

# --- Main Script ---

# Prompt user for input
read -p "Enter Title for the left panel (e.g., IN KÜRZE): " TITLE_LEFT
read -p "Enter pipe-separated list of items for the left panel (e.g., Item 1|Item 2): " ITEMS_LEFT
read -p "Enter Title for the right panel (e.g., FAKTEN): " TITLE_RIGHT
read -p "Enter pipe-separated list of items for the right panel (e.g., Fact 1|Fact 2): " ITEMS_RIGHT
read -p "Enter the output HTML file name (e.g., output.html): " OUTPUT_FILE


# Generate the list items HTML
LIST_ITEMS_LEFT=$(generate_list_items "$ITEMS_LEFT")
LIST_ITEMS_RIGHT=$(generate_list_items "$ITEMS_RIGHT")

# Create the HTML file using a heredoc
cat > "$OUTPUT_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Summary Slider</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        @import url('https://www.standardabweichung.de/fonts/st-matilda-info/stylesheet.css');
        body {
            font-family: 'STMatilda Info Variable', system-ui, sans-serif;
        }
    </style>
</head>
<body class="bg-gray-100 dark:bg-gray-800 flex items-center justify-center min-h-screen">

<div class="mx-auto w-full max-w-2xl">
    <div id="collapsible-content" class="w-full grow rounded-3xl border border-gray-200 dark:border-white/50 transition-all duration-500 ease-in-out">
        <div id="slider-container" class="relative flex w-full overflow-x-hidden rounded-3xl">
            
            <!-- Left Panel -->
            <div id="left-panel" class="relative z-[2] flex-shrink-0 bg-white px-4 py-4 pr-6 prose prose-sm dark:prose-invert w-content prose-p:my-3 prose-ul:list-none prose-ul:pl-0 flex flex-col items-start leading-tight text-black dark:bg-gray-700 dark:text-white/80 basis-3/4 transition-all duration-500 ease-in-out">
                <div class="bg-accent rounded-full px-4 py-1.5 text-xs font-semibold dark:text-black">${TITLE_LEFT}</div>
                <ul class="generated mt-2">
${LIST_ITEMS_LEFT}
                </ul>
            </div>

            <!-- Right Panel -->
            <div id="right-panel" class="bg-accent/30 dark:bg-accent/60 relative z-[1] flex-shrink-0 px-4 py-4 pl-6 prose prose-sm dark:prose-invert prose-p:my-3 prose-ul:list-none prose-ul:pl-0 w-content flex flex-col leading-tight text-black dark:text-white/80 basis-3/4 -translate-x-2/3 items-end transition-all duration-500 ease-in-out">
                <div class="bg-accent rounded-full px-4 py-1.5 text-xs font-semibold dark:text-black">${TITLE_RIGHT}</div>
                <ul class="generated mt-2 text-right">
${LIST_ITEMS_RIGHT}
                </ul>
            </div>

            <!-- Divider/Handle -->
            <div id="divider" class="absolute top-0 z-[2] h-full border-r-2 border-black transition-all duration-500 ease-in-out dark:border-gray-500 left-3/4 shadow-[-1px_0_3px_rgba(0,0,0,0.5)]">
                <button id="slider-button" class="absolute top-1/2 left-[1px] flex h-10 w-10 -translate-y-1/2 -translate-x-1/2 items-center justify-center rounded-full border-2 border-black bg-white dark:bg-gray-600 dark:border-gray-400" aria-label="Toggle Summary">
                    <svg id="slider-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="size-8 rotate-180 transition-transform duration-500 ease-in-out">
                        <polyline points="15 18 9 12 15 6"></polyline>
                    </svg>
                </button>
            </div>
        </div>
    </div>
    <div class="flex justify-center">
        <button id="collapse-button" class="mt-4 dark:text-gray-300 text-black" aria-label="Informationen ein-/ausblenden">
            <svg id="collapse-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="size-6 transition-transform duration-300">
                <path d="M5 12l14 0"></path>
            </svg>
        </button>
    </div>
</div>

<script>
    // Slider functionality
    const sliderButton = document.getElementById('slider-button');
    const leftPanel = document.getElementById('left-panel');
    const rightPanel = document.getElementById('right-panel');
    const divider = document.getElementById('divider');
    const sliderIcon = document.getElementById('slider-icon');

    let isOpen = false;

    sliderButton.addEventListener('click', () => {
        isOpen = !isOpen;
        if (isOpen) {
            // State: Expanded to show right panel
            leftPanel.classList.remove('basis-3/4');
            leftPanel.classList.add('basis-1/4');
            
            rightPanel.classList.remove('-translate-x-2/3');
            rightPanel.classList.add('-translate-x-0');

            divider.classList.remove('left-3/4');
            divider.classList.add('left-1/4');
            
            sliderIcon.classList.remove('rotate-180');
            sliderIcon.classList.add('rotate-0');

        } else {
            // State: Collapsed to show left panel
            leftPanel.classList.remove('basis-1/4');
            leftPanel.classList.add('basis-3/4');

            rightPanel.classList.remove('-translate-x-0');
            rightPanel.classList.add('-translate-x-2/3');
            
            divider.classList.remove('left-1/4');
            divider.classList.add('left-3/4');

            sliderIcon.classList.remove('rotate-0');
            sliderIcon.classList.add('rotate-180');
        }
    });

    // Collapse functionality
    const collapseButton = document.getElementById('collapse-button');
    const collapseIcon = document.getElementById('collapse-icon');
    const collapsibleContent = document.getElementById('collapsible-content');

    let isCollapsed = false;

    // Set initial max-height for smooth transition
    window.addEventListener('load', () => {
        collapsibleContent.style.maxHeight = collapsibleContent.scrollHeight + "px";
    });


    collapseButton.addEventListener('click', () => {
        isCollapsed = !isCollapsed;
        if (isCollapsed) {
            collapsibleContent.style.maxHeight = '0px';
            collapsibleContent.style.borderWidth = '0px';
            collapsibleContent.style.padding = '0px';
            collapseIcon.innerHTML = '<path d="M5 12l14 0"></path><path d="M12 5l0 14"></path>'; // Plus icon
        } else {
            collapsibleContent.style.maxHeight = collapsibleContent.scrollHeight + "px";
            collapsibleContent.style.borderWidth = '1px';
            collapsibleContent.style.padding = ''; // Reset padding
            collapseIcon.innerHTML = '<path d="M5 12l14 0"></path>'; // Minus icon
        }
    });
</script>

</body>
</html>
EOF

echo "Successfully created '$OUTPUT_FILE'"
echo "To use it, open the HTML file in a web browser."

# Make the script executable
chmod +x "$0"
