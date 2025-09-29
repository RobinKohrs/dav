#!/usr/bin/env bash

# --- DAV Common Configuration ---
# This file contains shared configuration and functions for all DAV helper scripts.
# It should be sourced by other scripts.

# --- Shared Configuration File Details ---
DAV_CONFIG_DIR="$HOME/.config/dav"
DAV_CONFIG_FILE_NAME="settings.ini"
DAV_CONFIG_FILE="$DAV_CONFIG_DIR/$DAV_CONFIG_FILE_NAME"

# --- Common Functions ---
check_dav_config() {
    if [ ! -f "$DAV_CONFIG_FILE" ]; then
        if $GUM_AVAILABLE; then
            gum style --foreground="yellow" --border="normal" --border-foreground="yellow" --padding="1 2" \
                      "Shared DAV configuration file not found:" \
                      "$DAV_CONFIG_FILE"
            if gum confirm "Create the configuration file at this location?" --default=true; then
                mkdir -p "$DAV_CONFIG_DIR" || { 
                    gum style --foreground="red" "Failed to create config directory: $DAV_CONFIG_DIR"
                    return 1
                }
                echo "# Main DAV Configuration - $DAV_CONFIG_FILE_NAME" > "$DAV_CONFIG_FILE"
                echo "" >> "$DAV_CONFIG_FILE"
                gum style --foreground="green" "Created configuration file at: $DAV_CONFIG_FILE"
                return 0
            else
                gum style --foreground="red" "Operation cancelled by user. Exiting."
                return 1
            fi
        else
            echo "Error: Shared DAV configuration file not found: $DAV_CONFIG_FILE"
            read -r -p "Create the configuration file at this location? [Y/n]: " response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                echo "Operation cancelled by user. Exiting."
                return 1
            fi
            mkdir -p "$DAV_CONFIG_DIR" || {
                echo "Failed to create config directory: $DAV_CONFIG_DIR"
                return 1
            }
            echo "# Main DAV Configuration - $DAV_CONFIG_FILE_NAME" > "$DAV_CONFIG_FILE"
            echo "" >> "$DAV_CONFIG_FILE"
            echo "Created configuration file at: $DAV_CONFIG_FILE"
            return 0
        fi
    fi
    return 0
}

# --- Gum Availability Check ---
GUM_AVAILABLE=false
if command -v gum &> /dev/null; then GUM_AVAILABLE=true; fi

# --- Export Common Variables ---
export DAV_CONFIG_DIR
export DAV_CONFIG_FILE_NAME
export DAV_CONFIG_FILE
export GUM_AVAILABLE 