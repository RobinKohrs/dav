#!/bin/bash

# --- Configuration ---
SCAN_DIR="."
LINK_DIR="$HOME/.local/bin"
SCRIPT_PATTERN="*.sh"
# --- End Configuration ---

# Ensure gum is installed
if ! command -v gum &> /dev/null; then
    echo "Error: gum is not installed. Please install it first."
    echo "Visit: https://github.com/charmbracelet/gum"
    exit 1
fi

# Ensure the link directory exists
mkdir -p "$LINK_DIR"
if [ ! -d "$LINK_DIR" ]; then
    gum style --bold --foreground="red" "Error: Could not create or find link directory: $LINK_DIR"
    exit 1
fi

# --- Helper functions for styled output ---
gum_success() { gum style --bold --foreground="green" "$@"; }
gum_warning() { gum style --bold --foreground="yellow" "$@"; }
gum_error() { gum style --bold --foreground="red" "$@"; }
gum_info() { gum style --foreground="blue" "$@"; }

# --- Function to get absolute path (tries realpath, falls back to a cd/pwd method) ---
get_absolute_path() {
    local path_to_resolve="$1"
    local resolved_path=""

    if command -v realpath &> /dev/null; then
        resolved_path=$(realpath -m "$path_to_resolve" 2>/dev/null) # -m allows non-existent components for some use cases
    fi

    if [ -z "$resolved_path" ] || [ ! -e "$path_to_resolve" ]; then # If realpath failed or path doesn't exist yet for it
        # Fallback for files/dirs: cd to dirname and get pwd of basename
        if [ -e "$path_to_resolve" ]; then
            local dir
            local base
            dir=$(dirname "$path_to_resolve")
            base=$(basename "$path_to_resolve")
            resolved_path="$(cd "$dir" &>/dev/null && pwd)/$base"
        else # If it truly doesn't exist, just return as is (for symlink targets that might be broken)
             resolved_path="$path_to_resolve"
        fi
    fi
    # Remove trailing slash if it's a directory and was added by cd/pwd logic
    [[ -d "$resolved_path" ]] && resolved_path="${resolved_path%/}"
    echo "$resolved_path"
}


# --- Find scripts and populate an array ---
gum_info "Scanning for '$SCRIPT_PATTERN' files in '$SCAN_DIR'..."
all_found_scripts=()
input_for_gum_choose=""

# Use find -print0 and while read -d '' to handle all filenames safely
while IFS= read -r -d $'\0' script_path; do
    # Get absolute path for reliable symlinking and display
    abs_script_path=$(get_absolute_path "$script_path")
    all_found_scripts+=("$abs_script_path")
    input_for_gum_choose+="${abs_script_path}\n"
done < <(find "$SCAN_DIR" -type f -name "$SCRIPT_PATTERN" -print0)


if [ ${#all_found_scripts[@]} -eq 0 ]; then
    gum_warning "No '$SCRIPT_PATTERN' scripts found in '$SCAN_DIR' or its subdirectories."
    exit 0
fi

# --- Let user select scripts using gum choose ---
# gum choose reads options from stdin if no arguments are given
selected_script_paths_str=$(echo -e "${input_for_gum_choose%\\n}" | \
    gum choose --no-limit \
               --cursor-prefix "[ ] " \
               --selected-prefix "[✓] " \
               --header "Select scripts to symlink to $LINK_DIR (Space to select, Enter to confirm):" \
               --height 20)

# Check if user cancelled (empty output from gum choose)
if [ -z "$selected_script_paths_str" ]; then
    gum_info "No scripts selected or selection cancelled. Exiting."
    exit 0
fi

# Convert newline-separated string from gum choose to an array
selected_scripts=()
while IFS= read -r line; do
    selected_scripts+=("$line")
done <<< "$selected_script_paths_str"


if [ ${#selected_scripts[@]} -eq 0 ]; then
    gum_info "No scripts selected. Exiting." # Should have been caught by -z check above, but defensive
    exit 0
fi

gum_info "\nProcessing selected scripts:"

for script_full_path in "${selected_scripts[@]}"; do
    script_name=$(basename "$script_full_path")
    target_link_path="$LINK_DIR/$script_name"

    echo
    gum_info "Processing: $script_name (from $script_full_path)"

    if [ ! -e "$script_full_path" ]; then
        gum_error "Source script '$script_full_path' no longer exists. Skipping."
        continue
    fi

    # 1. Ensure the original script is executable
    if [ ! -x "$script_full_path" ]; then
        if gum confirm "Script '$script_name' is not executable. Make it executable?"; then
            gum spin --title "Making $script_name executable..." -- chmod +x "$script_full_path"
            if [ $? -ne 0 ]; then
                gum_error "Failed to make $script_name executable. Skipping."
                continue
            else
                gum_success "$script_name is now executable."
            fi
        else
            gum_warning "Skipping $script_name as it's not executable and you chose not to change it."
            continue
        fi
    fi

    # 2. Check for existing symlink or file at the target location
    if [ -L "$target_link_path" ]; then
        existing_target_raw=$(readlink "$target_link_path")
        # Resolve existing_target to an absolute path for reliable comparison
        if [[ "$existing_target_raw" != /* ]]; then # If relative, resolve from link's dir
            resolved_existing_target=$(get_absolute_path "$LINK_DIR/$existing_target_raw")
        else
            resolved_existing_target=$(get_absolute_path "$existing_target_raw")
        fi

        if [ "$resolved_existing_target" == "$script_full_path" ]; then
            gum_success "✓ Symlink for '$script_name' already exists and points correctly."
            continue
        else
            if gum confirm "Symlink '$script_name' in $LINK_DIR points to '$resolved_existing_target' (expected '$script_full_path'). Overwrite?"; then
                gum spin --title "Replacing symlink for $script_name..." -- bash -c "rm -f '$target_link_path' && ln -s '$script_full_path' '$target_link_path'"
                [ $? -eq 0 ] && gum_success "✓ Symlink for '$script_name' updated." || gum_error "✗ Failed to update symlink for '$script_name'."
            else
                gum_warning "Skipped updating symlink for '$script_name'."
            fi
        fi
    elif [ -e "$target_link_path" ]; then
        if gum confirm "File '$script_name' exists in $LINK_DIR and is NOT a symlink. Replace with symlink to '$script_full_path'?"; then
            gum spin --title "Replacing file $script_name with symlink..." -- bash -c "rm -f '$target_link_path' && ln -s '$script_full_path' '$target_link_path'"
            [ $? -eq 0 ] && gum_success "✓ File '$script_name' replaced with symlink." || gum_error "✗ Failed to replace file '$script_name'."
        else
            gum_warning "Skipped replacing file '$script_name'."
        fi
    else
        gum spin --title "Linking $script_name..." -- ln -s "$script_full_path" "$target_link_path"
        [ $? -eq 0 ] && gum_success "✓ Symlink for '$script_name' created." || gum_error "✗ Failed to create symlink for '$script_name'."
    fi
done

echo
gum_success "\nAll selected operations complete!"
gum_info "Ensure '$LINK_DIR' is in your PATH to run these scripts by name."
gum_info "You might need to open a new terminal or re-source your shell config (e.g., 'source ~/.zshrc')."
