#!/usr/bin/env bash

# --- Load Shared Configuration ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/../common/dav_common.sh" || { echo "Config failed"; return 1; }

# --- Script Configuration ---
SCRIPT_NAME="dav-navigation"

# Function to get the absolute path of the dav directory
get_dav_dir() {
    # Check if DAV_DIR is already set in settings.ini
    if [ -f "$DAV_CONFIG_FILE" ]; then
        local current_dir
        current_dir="$(grep "^DAV_DIR=" "$DAV_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"')"
        if [ -n "$current_dir" ] && [ -d "$current_dir" ] && [ -d "$current_dir/wiki" ]; then
            echo "$current_dir"
            return 0
        fi
    fi

    # Prompt for the DAV directory path
    local dav_dir
    dav_dir="$(gum input --prompt "Enter the absolute path to your DAV directory: " --placeholder "/path/to/your/dav")"
    
    # Validate the path
    if [ ! -d "$dav_dir" ]; then
        gum style --foreground="red" "Error ($SCRIPT_NAME): Directory does not exist: $dav_dir"
        exit 1
    fi
    
    # Check if it's a valid DAV directory
    if [ ! -d "$dav_dir/wiki" ]; then
        gum style --foreground="red" "Error ($SCRIPT_NAME): Not a valid DAV directory (wiki folder not found): $dav_dir"
        exit 1
    fi

    # Add or update DAV_DIR in settings.ini
    if grep -q "^DAV_DIR=" "$DAV_CONFIG_FILE"; then
        # Update existing entry
        sed -i.bak "s|^DAV_DIR=.*|DAV_DIR=\"$dav_dir\"|" "$DAV_CONFIG_FILE"
    else
        # Add new entry
        echo "DAV_DIR=\"$dav_dir\"" >> "$DAV_CONFIG_FILE"
    fi
    
    echo "$dav_dir"
}

# --- Main Script ---
# Check for config file existence first
check_dav_config || exit 1

# Check for gum
if ! command -v gum >/dev/null 2>&1; then
    echo "Error: 'gum' is required but not installed. Please install it first:"
    echo "  brew install gum  # for macOS"
    echo "  https://github.com/charmbracelet/gum#installation  # for other systems"
    exit 1
fi

# Get the DAV directory
dav_dir="$(get_dav_dir)"

# Change to the DAV directory
cd "$dav_dir" || { echo "Error: Could not change to DAV directory"; exit 1; }

# If a subdirectory is specified, try to cd into it
if [ -n "$1" ]; then
    if [ -d "$1" ]; then
        cd "$1" || { echo "Error: Could not change to $1"; exit 1; }
    else
        echo "Error: Subdirectory $1 does not exist"
        exit 1
    fi
fi

# Show current directory structure
if command -v tree >/dev/null 2>&1; then
    echo "Current DAV directory structure:"
    tree -L 2 -a -I ".git|.Rproj.user|.venv|__pycache__|.DS_Store|.quarto" .
else
    echo "Current directory: $(pwd)"
    ls -la
fi

exit 0 