#!/usr/bin/env zsh

# --- Configuration ---
SCAN_DIR="."
LINK_DIR="$HOME/.local/bin"
SCRIPT_PATTERN="*.sh"
# Exclude macOS metadata files
EXCLUDE_PATTERN="._*"
# --- End Configuration ---

# --- Helper functions for styled output ---
gum_success() { gum style --bold --foreground="green" "$@"; }
gum_warning() { gum style --bold --foreground="yellow" "$@"; }
gum_error() { gum style --bold --foreground="red" "$@"; }
gum_info() { gum style --foreground="blue" "$@"; }

# --- Function to setup dav navigation ---
setup_dav_navigation() {
    local dav_dir
    local nav_script_path
    local target_link_path

    # Get the absolute path of the dav directory (where setup.sh is located)
    dav_dir="$(dirname "$(get_absolute_path "$0")")"
    nav_script_path="$dav_dir/wiki/helper_scripts/setup_dav_navigation.sh"
    target_link_path="$LINK_DIR/dav"

    # Verify the navigation script exists
    if [ ! -f "$nav_script_path" ]; then
        gum_error "Navigation script not found at: $nav_script_path"
        return 1
    fi

    # Make sure the script is executable
    if [ ! -x "$nav_script_path" ]; then
        if gum confirm "Navigation script is not executable. Make it executable?"; then
            gum spin --title "Making navigation script executable..." -- chmod +x "$nav_script_path"
            if [ $? -ne 0 ]; then
                gum_error "Failed to make navigation script executable."
                return 1
            fi
            gum_success "Navigation script is now executable."
        else
            gum_warning "Skipping navigation script as it's not executable."
            return 1
        fi
    fi

    # Create or update the symlink
    if [ -L "$target_link_path" ]; then
        existing_target=$(readlink "$target_link_path")
        if [ "$existing_target" = "$nav_script_path" ]; then
            gum_success "✓ Symlink for 'dav' already exists and points correctly."
        else
            if gum confirm "Symlink 'dav' points to '$existing_target'. Update to point to '$nav_script_path'?"; then
                gum spin --title "Updating dav symlink..." -- bash -c "rm -f '$target_link_path' && ln -s '$nav_script_path' '$target_link_path'"
                [ $? -eq 0 ] && gum_success "✓ Symlink for 'dav' updated." || gum_error "✗ Failed to update symlink for 'dav'."
            else
                gum_warning "Skipped updating symlink for 'dav'."
            fi
        fi
    else
        gum spin --title "Creating dav symlink..." -- ln -s "$nav_script_path" "$target_link_path"
        [ $? -eq 0 ] && gum_success "✓ Symlink for 'dav' created." || gum_error "✗ Failed to create symlink for 'dav'."
    fi
}

# --- Function to get absolute path (tries realpath, falls back to a cd/pwd method) ---
get_absolute_path() {
    local path_to_resolve="$1"
    local resolved_path=""

    if command -v realpath &> /dev/null; then
        resolved_path=$(realpath -m "$path_to_resolve" 2>/dev/null)
    fi

    if [ -z "$resolved_path" ] || [ ! -e "$path_to_resolve" ]; then
        if [ -e "$path_to_resolve" ]; then
            local dir
            local base
            dir=$(dirname "$path_to_resolve")
            base=$(basename "$path_to_resolve")
            resolved_path="$(cd "$dir" &>/dev/null && pwd)/$base"
        else
            resolved_path="$path_to_resolve"
        fi
    fi
    [[ -d "$resolved_path" ]] && resolved_path="${resolved_path%/}"
    echo "$resolved_path"
}

# --- Function to list existing symlinks ---
list_existing_symlinks() {
    local link_dir="$1"
    local found_links=()
    
    # Enable nullglob for this function to handle empty directories
    local old_nullglob
    old_nullglob=$(shopt -p nullglob 2>/dev/null)
    shopt -s nullglob 2>/dev/null || setopt nullglob 2>/dev/null
    
    # Just list the filenames in the link directory
    if [ -d "$link_dir" ]; then
        for link in "$link_dir"/*; do
            if [ -L "$link" ]; then
                found_links+=("$(basename "$link")")
            fi
        done
    fi
    
    # Restore original nullglob setting
    eval "$old_nullglob" 2>/dev/null || unsetopt nullglob 2>/dev/null
    
    if [ ${#found_links[@]} -eq 0 ]; then
        gum_info "No helper scripts currently symlinked in $link_dir"
    else
        gum_info "Currently symlinked helper scripts in $link_dir:"
        printf '%s\n' "${found_links[@]}" | sort
    fi
    echo
}

# --- Main Script ---
# Ensure gum is installed
if ! command -v gum &> /dev/null; then
    gum_error "gum is not installed. Please install it first."
    echo "Visit: https://github.com/charmbracelet/gum"
    exit 1
fi

# Ensure the link directory exists
mkdir -p "$LINK_DIR"
if [ ! -d "$LINK_DIR" ]; then
    gum_error "Could not create or find link directory: $LINK_DIR"
    exit 1
fi

# Setup dav navigation first
gum_info "Setting up DAV navigation..."
setup_dav_navigation

# Add a blank line for better readability
echo

# Show existing symlinks
list_existing_symlinks "$LINK_DIR"

# --- Find scripts and populate an array ---
gum_info "Scanning for '$SCRIPT_PATTERN' files in '$SCAN_DIR'..."
all_found_scripts=()
input_for_gum_choose=""

# Use find with -not -name to exclude ._ files
while IFS= read -r -d $'\0' script_path; do
    abs_script_path=$(get_absolute_path "$script_path")
    script_name=$(basename "$abs_script_path")
    target_link_path="$LINK_DIR/$script_name"

    # Check if already correctly symlinked
    if [ -L "$target_link_path" ]; then
        existing_target_raw=$(readlink "$target_link_path")
        local resolved_existing_target # Local to this block
        if [[ "$existing_target_raw" != /* ]]; then
            # Resolve relative symlink target from LINK_DIR
            resolved_existing_target=$(get_absolute_path "$LINK_DIR/$existing_target_raw")
        else
            # Absolute symlink target
            resolved_existing_target=$(get_absolute_path "$existing_target_raw")
        fi

        if [[ "$resolved_existing_target" == "$abs_script_path" ]]; then
            # Already correctly symlinked, skip adding to selection list
            gum_info "✓ '$script_name' is already correctly symlinked. Skipping from selection."
            continue
        fi
    fi

    all_found_scripts+=("$abs_script_path")
    input_for_gum_choose+="${abs_script_path}\n"
done < <(find "$SCAN_DIR" -type f -name "$SCRIPT_PATTERN" -not -name "._*" -print0)

if [ ${#all_found_scripts[@]} -eq 0 ]; then
    gum_warning "No '$SCRIPT_PATTERN' scripts found in '$SCAN_DIR' or its subdirectories."
    exit 0
fi

# --- Let user select scripts using gum choose ---
selected_script_paths_str=$(echo -e "${input_for_gum_choose%\\n}" | \
    gum choose --no-limit \
               --cursor-prefix "[ ] " \
               --selected-prefix "[✓] " \
               --header "Select scripts to symlink to $LINK_DIR (Space to select, Enter to confirm):" \
               --height 20)

# Check if user cancelled
if [ -z "$selected_script_paths_str" ]; then
    gum_info "No scripts selected or selection cancelled. Exiting."
    exit 0
fi

# Convert newline-separated string to array
selected_scripts=()
while IFS= read -r line; do
    selected_scripts+=("$line")
done <<< "$selected_script_paths_str"

if [ ${#selected_scripts[@]} -eq 0 ]; then
    gum_info "No scripts selected. Exiting."
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
        if [[ "$existing_target_raw" != /* ]]; then
            resolved_existing_target=$(get_absolute_path "$LINK_DIR/$existing_target_raw")
        else
            resolved_existing_target=$(get_absolute_path "$existing_target_raw")
        fi

        if [[ "$resolved_existing_target" == "$script_full_path" ]]; then
            gum_success "✓ Symlink for '$script_name' already exists and points correctly."
            continue
        else
            # Symlink exists but points to the wrong target.
            # Per user request: do not prompt if already a symlink. Silently correct it.
            gum_warning "Symlink '$script_name' in $LINK_DIR pointed to '$resolved_existing_target'. Correcting to point to '$script_full_path'."
            gum spin --title "Correcting symlink for $script_name..." -- bash -c "rm -f '$target_link_path' && ln -s '$script_full_path' '$target_link_path'"
            if [ $? -eq 0 ]; then
                gum_success "✓ Symlink for '$script_name' corrected."
            else
                gum_error "✗ Failed to correct symlink for '$script_name'."
            fi
            continue # Ensure we proceed to the next script
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
gum_success "Setup complete! You can now:"
gum_info "1. Use 'dav' to navigate to the DAV directory"
gum_info "2. Use 'dav-helpers' to go to the helper scripts directory"
gum_info "3. Run any of the symlinked scripts from anywhere (they're in $LINK_DIR)"
