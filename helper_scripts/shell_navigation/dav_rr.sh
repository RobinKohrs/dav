#!/usr/bin/env bash

# --- Load Shared Configuration ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/../common/dav_common.sh" || {
    echo "Error: Unable to source dav_common.sh"
    exit 1
}

# --- Script Configuration ---
SCRIPT_NAME="rr"
R_SCRIPTS_DIR_KEY="R_SCRIPTS_DIR"

# --- Helper Functions ---
get_r_scripts_dir() {
    # Check if R_SCRIPTS_DIR is already set in settings.ini
    if [ -f "$DAV_CONFIG_FILE" ]; then
        local current_dir
        current_dir="$(grep "^$R_SCRIPTS_DIR_KEY=" "$DAV_CONFIG_FILE" | cut -d'=' -f2- | tr -d '"')"
        if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
            echo "$current_dir"
            return 0
        fi
    fi

    # Prompt for the R scripts directory path
    local r_scripts_dir
    if $GUM_AVAILABLE; then
        r_scripts_dir="$(gum input --prompt "Enter the directory where R scripts should be stored: " --placeholder "/path/to/your/r-scripts")"
    else
        read -r -p "Enter the directory where R scripts should be stored: " r_scripts_dir
    fi
    
    # Validate and create the path if it doesn't exist
    if [ -z "$r_scripts_dir" ]; then
        if $GUM_AVAILABLE; then
            gum style --foreground="red" "Error ($SCRIPT_NAME): No directory specified"
        else
            echo "Error ($SCRIPT_NAME): No directory specified"
        fi
        exit 1
    fi
    
    # Expand tilde if present
    r_scripts_dir="${r_scripts_dir/#\~/$HOME}"
    
    # Create directory if it doesn't exist
    if [ ! -d "$r_scripts_dir" ]; then
        if $GUM_AVAILABLE; then
            if gum confirm "Directory doesn't exist. Create $r_scripts_dir?" --default=true; then
                mkdir -p "$r_scripts_dir" || {
                    gum style --foreground="red" "Error ($SCRIPT_NAME): Failed to create directory: $r_scripts_dir"
                    exit 1
                }
                gum style --foreground="green" "Created directory: $r_scripts_dir"
            else
                gum style --foreground="red" "Operation cancelled by user. Exiting."
                exit 1
            fi
        else
            read -r -p "Directory doesn't exist. Create $r_scripts_dir? [Y/n]: " response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                echo "Operation cancelled by user. Exiting."
                exit 1
            fi
            mkdir -p "$r_scripts_dir" || {
                echo "Error ($SCRIPT_NAME): Failed to create directory: $r_scripts_dir"
                exit 1
            }
            echo "Created directory: $r_scripts_dir"
        fi
    fi

    # Add or update R_SCRIPTS_DIR in settings.ini
    if grep -q "^$R_SCRIPTS_DIR_KEY=" "$DAV_CONFIG_FILE"; then
        # Update existing entry
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i .bak "s|^$R_SCRIPTS_DIR_KEY=.*|$R_SCRIPTS_DIR_KEY=\"$r_scripts_dir\"|" "$DAV_CONFIG_FILE"
        else
            # Linux
            sed -i.bak "s|^$R_SCRIPTS_DIR_KEY=.*|$R_SCRIPTS_DIR_KEY=\"$r_scripts_dir\"|" "$DAV_CONFIG_FILE"
        fi
    else
        # Add new entry
        echo "$R_SCRIPTS_DIR_KEY=\"$r_scripts_dir\"" >> "$DAV_CONFIG_FILE"
    fi
    
    echo "$r_scripts_dir"
}

create_year_month_dir() {
    local base_dir="$1"
    local year_month
    year_month="$(date +%Y_%m)"
    local target_dir="$base_dir/$year_month"
    
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir" || {
            if $GUM_AVAILABLE; then
                gum style --foreground="red" "Error ($SCRIPT_NAME): Failed to create directory: $target_dir"
            else
                echo "Error ($SCRIPT_NAME): Failed to create directory: $target_dir"
            fi
            exit 1
        }
        if $GUM_AVAILABLE; then
            gum style --foreground="green" "Created directory: $target_dir"
        else
            echo "Created directory: $target_dir"
        fi
    fi
    
    echo "$target_dir"
}

create_r_file() {
    local target_dir="$1"
    local script_name="$2"
    
    # Ensure the script name ends with .R
    if [[ ! "$script_name" =~ \.R$ ]]; then
        script_name="${script_name}.R"
    fi
    
    local full_path="$target_dir/$script_name"
    
    # Check if file already exists
    if [ -f "$full_path" ]; then
        if $GUM_AVAILABLE; then
            if ! gum confirm "File $full_path already exists. Overwrite?" --default=false; then
                gum style --foreground="yellow" "Operation cancelled. File not overwritten."
                exit 0
            fi
        else
            read -r -p "File $full_path already exists. Overwrite? [y/N]: " response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Operation cancelled. File not overwritten."
                exit 0
            fi
        fi
    fi
    
    # Create the R file (empty)
    touch "$full_path"
    
    echo "$full_path"
}

show_usage() {
    echo "Usage: $SCRIPT_NAME [script_name]"
    echo ""
    echo "Creates a new R script in the configured directory structure."
    echo "Files are organized as: <r_scripts_dir>/<year>_<month>/<script_name>.R"
    echo ""
    echo "Arguments:"
    echo "  script_name    Name of the R script to create (optional, will prompt if not provided)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME analysis"
    echo "  $SCRIPT_NAME data_processing.R"
    echo ""
    echo "Configuration:"
    echo "  R scripts directory is stored in: $DAV_CONFIG_FILE"
    echo "  Key: $R_SCRIPTS_DIR_KEY"
}

# --- Main Script ---
# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check for config file existence first
check_dav_config || exit 1

# Get script name from argument or prompt
script_name="$1"
if [ -z "$script_name" ]; then
    if $GUM_AVAILABLE; then
        script_name="$(gum input --prompt "Enter the R script name: " --placeholder "my_analysis")"
    else
        read -r -p "Enter the R script name: " script_name
    fi
    
    if [ -z "$script_name" ]; then
        if $GUM_AVAILABLE; then
            gum style --foreground="red" "Error ($SCRIPT_NAME): No script name provided"
        else
            echo "Error ($SCRIPT_NAME): No script name provided"
        fi
        exit 1
    fi
fi

# Get the R scripts directory
r_scripts_dir="$(get_r_scripts_dir)"

# Create year_month directory
year_month_dir="$(create_year_month_dir "$r_scripts_dir")"

# Create the R file
r_file_path="$(create_r_file "$year_month_dir" "$script_name")"

# Success message
if $GUM_AVAILABLE; then
    gum style --foreground="green" --border="normal" --border-foreground="green" --padding="1 2" \
              "✓ R script created successfully!" \
              "Path: $r_file_path"
else
    echo "✓ R script created successfully!"
    echo "Path: $r_file_path"
fi

# Ask user which editor to use
open_file_in_editor() {
    local file_path="$1"
    local available_editors=()
    local editor_commands=()
    
    # Check which editors are available
    if command -v code >/dev/null 2>&1; then
        available_editors+=("Cursor (VS Code)")
        editor_commands+=("code")
    fi
    
    if [ -d "/Applications/RStudio.app" ]; then
        available_editors+=("RStudio")
        editor_commands+=("open -a RStudio")
    fi
    
    if command -v vim >/dev/null 2>&1; then
        available_editors+=("vim")
        editor_commands+=("vim")
    fi
    
    # If no editors are available, just return
    if [ ${#available_editors[@]} -eq 0 ]; then
        if $GUM_AVAILABLE; then
            gum style --foreground="yellow" "No supported editors found (Cursor, RStudio, or vim)"
        else
            echo "No supported editors found (Cursor, RStudio, or vim)"
        fi
        return
    fi
    
    # If only one editor is available, ask if they want to use it
    if [ ${#available_editors[@]} -eq 1 ]; then
        if $GUM_AVAILABLE; then
            if gum confirm "Open the file in ${available_editors[0]}?" --default=true; then
                eval "${editor_commands[0]} \"$file_path\""
            fi
        else
            read -r -p "Open the file in ${available_editors[0]}? [Y/n]: " response
            if [[ ! "$response" =~ ^[Nn]$ ]]; then
                eval "${editor_commands[0]} \"$file_path\""
            fi
        fi
        return
    fi
    
    # Multiple editors available - let user choose
    if $GUM_AVAILABLE; then
        # Add "Don't open" option
        available_editors+=("Don't open")
        editor_commands+=("")
        
        local choice
        choice=$(gum choose --header "Choose an editor to open the file:" "${available_editors[@]}")
        
        # Find the index of the selected choice
        for i in "${!available_editors[@]}"; do
            if [[ "${available_editors[$i]}" == "$choice" ]]; then
                if [ -n "${editor_commands[$i]}" ]; then
                    eval "${editor_commands[$i]} \"$file_path\""
                fi
                break
            fi
        done
    else
        echo "Choose an editor to open the file:"
        for i in "${!available_editors[@]}"; do
            echo "$((i+1)). ${available_editors[$i]}"
        done
        echo "$((${#available_editors[@]}+1)). Don't open"
        
        read -r -p "Enter your choice (1-$((${#available_editors[@]}+1))): " choice
        
        # Validate choice and execute
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#available_editors[@]} ]; then
            local index=$((choice-1))
            if [ -n "${editor_commands[$index]}" ]; then
                eval "${editor_commands[$index]} \"$file_path\""
            fi
        elif [ "$choice" -eq $((${#available_editors[@]}+1)) ]; then
            echo "File not opened."
        else
            echo "Invalid choice. File not opened."
        fi
    fi
}

# Open the file with the chosen editor
open_file_in_editor "$r_file_path"

exit 0
