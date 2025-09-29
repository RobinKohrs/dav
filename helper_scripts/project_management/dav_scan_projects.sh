#!/usr/bin/env bash

# DAV Project Scanner
# Automatically scan and add existing projects to the project manager

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
PROJECT_MANAGER_SCRIPT="$SCRIPT_DIR/dav_project_manager.sh"

# Source the project manager
if [ -f "$PROJECT_MANAGER_SCRIPT" ]; then
    source "$PROJECT_MANAGER_SCRIPT"
else
    echo "Error: Project manager script not found!"
    exit 1
fi

# Default scan directory
SCAN_DIR="$HOME/projects"

# Function to detect project type
detect_project_type() {
    local project_path="$1"
    
    # Check for R project
    if find "$project_path" -name "*.Rproj" -type f | grep -q .; then
        # Check if also has QGIS
        if find "$project_path" -name "*.qgs" -type f | grep -q .; then
            echo "geospatial"
        else
            echo "r-analysis"
        fi
    # Check for QGIS only
    elif find "$project_path" -name "*.qgs" -type f | grep -q .; then
        echo "qgis"
    else
        echo "mixed"
    fi
}

# Function to scan directory
scan_directory() {
    local scan_dir="$1"
    
    if [ ! -d "$scan_dir" ]; then
        echo "Directory does not exist: $scan_dir"
        return 1
    fi
    
    echo "🔍 Scanning directory: $scan_dir"
    echo ""
    
    local found_projects=0
    local added_projects=0
    
    # Find all directories that look like projects
    while IFS= read -r -d '' project_dir; do
        local project_name=$(basename "$project_dir")
        local project_type=$(detect_project_type "$project_dir")
        
        found_projects=$((found_projects + 1))
        
        # Check if project already exists
        if jq -e --arg name "$project_name" '.projects[] | select(.name == $name)' "$PROJECTS_CONFIG_FILE" > /dev/null 2>&1; then
            if command -v gum >/dev/null 2>&1; then
                gum style --foreground="yellow" "⚠️  '$project_name' already exists (skipping)"
            else
                echo "⚠️  '$project_name' already exists (skipping)"
            fi
        else
            # Add the project
            add_project "$project_name" "$project_dir" "$project_type"
            added_projects=$((added_projects + 1))
        fi
        
    done < <(find "$scan_dir" -type d -maxdepth 3 -mindepth 1 \( -name "*.Rproj" -o -name "*.qgs" -o -name "R" -o -name "qgis" \) -exec dirname {} \; | sort -u -z)
    
    echo ""
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground="green" --border="normal" --border-foreground="green" --padding="1 2" \
                  "✅ Scan complete!" \
                  "Found: $found_projects projects" \
                  "Added: $added_projects new projects"
    else
        echo "✅ Scan complete!"
        echo "Found: $found_projects projects"
        echo "Added: $added_projects new projects"
    fi
}

# Main function
main() {
    local scan_dir="$1"
    
    if [ -z "$scan_dir" ]; then
        if command -v gum >/dev/null 2>&1; then
            scan_dir=$(gum input --header "📁 Directory to scan:" --value "$SCAN_DIR")
        else
            read -p "Directory to scan [$SCAN_DIR]: " scan_dir
            scan_dir="${scan_dir:-$SCAN_DIR}"
        fi
    fi
    
    # Expand ~ and make absolute
    scan_dir="${scan_dir/#\~/$HOME}"
    scan_dir=$(realpath "$scan_dir" 2>/dev/null || echo "$scan_dir")
    
    scan_directory "$scan_dir"
}

# Show help
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground="cyan" --border="double" --border-foreground="cyan" --padding="1 2" \
                  "🔍 DAV Project Scanner" \
                  "Automatically find and add existing projects"
        echo ""
        gum style --foreground="yellow" "Usage:"
        echo "  $0 [directory]     # Scan specific directory"
        echo "  $0                 # Interactive directory selection"
        echo "  $0 help            # Show this help"
        echo ""
        gum style --foreground="yellow" "Examples:"
        echo "  $0 ~/projects      # Scan ~/projects directory"
        echo "  $0 ~/work          # Scan ~/work directory"
        echo "  $0                 # Interactive mode"
    else
        echo "DAV Project Scanner"
        echo "Automatically find and add existing projects"
        echo ""
        echo "Usage:"
        echo "  $0 [directory]     # Scan specific directory"
        echo "  $0                 # Interactive directory selection"
        echo "  $0 help            # Show this help"
    fi
    exit 0
fi

# Run main function
main "$1"
