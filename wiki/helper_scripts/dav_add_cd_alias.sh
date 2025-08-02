#!/usr/bin/env bash
# set -x # Keep commented out unless actively debugging

# --- Load Shared Configuration ---
source "$(cd "$(dirname -- "$(readlink -f -- "$0")")" && pwd)/dav_common.sh" || exit 1

# --- Script Information ---
SCRIPT_NAME="add-cd-alias"

# --- Dependency Check Variables ---
GUM_AVAILABLE=false
if command -v gum &> /dev/null; then GUM_AVAILABLE=true; fi

REALPATH_CMD=""
if command -v realpath &>/dev/null && realpath -m . &>/dev/null; then REALPATH_CMD="realpath";
elif command -v grealpath &>/dev/null && grealpath -m . &>/dev/null; then REALPATH_CMD="grealpath"; fi
warned_no_realpath_cmd=false

# --- Helper Functions with Gum Styling ---
_print_gum_message() {
    local type="$1"; local message="$2"; local details="$3"; local prefix=""; local style_args=(); local target_stream=stdout
    case "$type" in
        error) prefix="❌ ERROR ($SCRIPT_NAME):"; style_args+=("--foreground" "red" "--bold"); target_stream=stderr;;
        warning) prefix="⚠️ WARNING ($SCRIPT_NAME):"; style_args+=("--foreground" "yellow"); target_stream=stderr;;
        success) prefix="✅ SUCCESS ($SCRIPT_NAME):"; style_args+=("--foreground" "green" "--bold");;
        info) prefix="ℹ️ ($SCRIPT_NAME):"; style_args+=("--foreground" "blue"); target_stream=stderr;; # info to stderr for progress like messages
        header)
            if $GUM_AVAILABLE; then gum style --padding "1 0" --border double --border-foreground 159 --align center --width 60 "$message" >&2;
            else echo "" >&2 && echo "--- $message ---" >&2; fi
            if [[ -n "$details" ]]; then echo "$details" >&2; fi; return ;;
        plain) echo "$message" >&2; return ;; # Prompts to stderr
        *) echo "> $message" >&2; if [[ -n "$details" ]]; then echo "  $details" >&2; fi; return ;;
    esac

    if $GUM_AVAILABLE; then
        local full_message="$prefix $message"
        if [[ "$target_stream" == "stderr" ]]; then
            gum style "${style_args[@]}" "$full_message" >&2
            if [[ -n "$details" ]]; then gum style --faint "   $details" >&2; fi
        else # stdout
            gum style "${style_args[@]}" "$full_message"
            if [[ -n "$details" ]]; then gum style --faint "   $details"; fi
        fi
    else # Plain text fallback
        if [[ "$type" == "error" || "$type" == "warning" || "$type" == "header" || "$type" == "plain" || "$type" == "info" ]]; then echo "" >&"$target_stream"; fi
        echo "$prefix $message" >&"$target_stream"
        if [[ -n "$details" ]]; then echo "    $details" >&"$target_stream"; fi
        if [[ "$type" == "error" || "$type" == "warning" || "$type" == "success" || "$type" == "header" || "$type" == "info" ]]; then echo "" >&"$target_stream"; fi
    fi
    if [[ "$type" == "error" ]]; then exit 1; fi
}

print_error()   { _print_gum_message "error" "$1" "$2"; }
print_success() { _print_gum_message "success" "$1" "$2"; }
print_warning() { _print_gum_message "warning" "$1" "$2"; }
print_info()    { _print_gum_message "info" "$1" "$2"; }
print_header()  { _print_gum_message "header" "$1" "$2"; }
print_plain()   { _print_gum_message "plain" "$1"; }

show_help() {
    local help_text
    read -r -d '' help_text_content <<EOF
# $SCRIPT_NAME Help
**Usage:** \`$SCRIPT_NAME [-h]\`
Prompts for a directory and an alias, then adds a 'cd' alias to your .zshrc file.

This script will add a line to your ~/.zshrc file like this:
alias <your_alias>='cd "/path/to/your/directory"'

## Options
  \`-h\`         Show this help message and exit.
EOF
    help_text="$help_text_content"
    if $GUM_AVAILABLE; then gum format --theme pretty "$help_text"; else echo -e "$help_text"; fi
    exit 0;
}

normalize_path_absolute() {
    local path_to_normalize="$1"; local normalized_output
    if [[ -z "$path_to_normalize" ]]; then echo ""; return; fi
    if [[ "${path_to_normalize:0:1}" == "~" ]]; then path_to_normalize="$HOME${path_to_normalize:1}"; fi
    if [[ "$path_to_normalize" != /* ]]; then path_to_normalize="$PWD/$path_to_normalize"; fi
    
    if [[ -n "$REALPATH_CMD" ]]; then 
        normalized_output=$($REALPATH_CMD -m "$path_to_normalize")
    else
        if ! $warned_no_realpath_cmd ; then 
            print_warning "realpath -m (or grealpath -m) not found. Path normalization might be less robust."
            warned_no_realpath_cmd=true
        fi
        local old_pwd; old_pwd=$(pwd)
        local dir_part; dir_part=$(dirname "$path_to_normalize")
        local file_part; file_part=$(basename "$path_to_normalize")
        
        if cd "$dir_part" &>/dev/null; then 
            normalized_output="$(pwd)/$file_part"
            cd "$old_pwd"
        else 
            normalized_output="$path_to_normalize" # Fallback if cd fails
        fi
    fi
    if [[ "$normalized_output" != "/" && "${normalized_output: -1}" == "/" ]]; then 
        normalized_output="${normalized_output%/}"
    fi
    echo "$normalized_output"
}

# --- Argument Parsing ---
while getopts ":h" opt; do
  case "$opt" in
    h) show_help ;;
    \?) print_error "Invalid option: -$OPTARG. Use -h for help." ;;
  esac
done
shift $((OPTIND-1))

# --- Main Script Logic ---
main() {
    print_header "$SCRIPT_NAME" "Add a new 'cd' alias to .zshrc"

    # --- Step 1: Get Directory ---
    local dir_path_raw dir_path
    local current_dir; current_dir=$(pwd)
    print_plain "Enter the directory to alias (default: current directory)"
    if $GUM_AVAILABLE; then
        dir_path_raw=$(gum input --value="$current_dir" --placeholder="Enter path...")
    else
        read -r -p "> " dir_path_raw
    fi
    dir_path_raw=${dir_path_raw:-$current_dir}
    dir_path=$(normalize_path_absolute "$dir_path_raw")

    if [[ ! -d "$dir_path" ]]; then
        print_error "Directory not found: $dir_path"
    fi

    # --- Step 2: Get Alias Name ---
    local alias_name_raw alias_name
    print_plain "Enter the name for the new alias:"
    if $GUM_AVAILABLE; then
        alias_name_raw=$(gum input --placeholder="e.g., proj, docs, downloads")
    else
        read -r -p "> " alias_name_raw
    fi
    alias_name=$(echo "$alias_name_raw" | xargs) # trim whitespace

    if [[ -z "$alias_name" ]]; then print_error "Alias name cannot be empty."; fi
    if ! [[ "$alias_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid alias name." "Alias names can only contain letters, numbers, underscores, and hyphens."
    fi
    if command -v "$alias_name" &>/dev/null; then
        print_warning "An alias or command named '$alias_name' already exists. Overwriting it is not recommended."
        local confirm_overwrite=false
        if $GUM_AVAILABLE; then
            gum confirm "Continue anyway?" || exit 0
        else
            read -r -p "Continue anyway? [y/N]: " c
            if [[ ! "$c" =~ ^[Yy]$ ]]; then
                print_info "Operation cancelled."
                exit 0
            fi
        fi
    fi

    # --- Step 3: Add to .zshrc ---
    local zshrc_file="$HOME/.zshrc"
    if [ ! -f "$zshrc_file" ]; then
        print_error ".zshrc file not found at $zshrc_file"
    fi

    local alias_line="alias $alias_name='cd \"$dir_path\"'"
    local comment_line="# Alias for '$alias_name' to '$dir_path' added by $SCRIPT_NAME on $(date)"

    # Check if alias already exists
    if grep -q "alias $alias_name=" "$zshrc_file"; then
        print_warning "Alias '$alias_name' already seems to exist in $zshrc_file."
        # Could offer to replace it here, for now we just warn and append
    fi

    print_info "Adding the following to $zshrc_file:"
    print_plain "$comment_line"
    print_plain "$alias_line"

    local confirm_add=false
    if $GUM_AVAILABLE; then
        gum confirm "Proceed with adding this to your .zshrc?" && confirm_add=true
    else
        read -r -p "Proceed? [Y/n]: " c
        if [[ ! "$c" =~ ^[Nn]$ ]]; then confirm_add=true; fi
    fi

    if $confirm_add; then
        {
            echo ""
            echo "$comment_line"
            echo "$alias_line"
        } >> "$zshrc_file"
        print_success "Alias '$alias_name' added to $zshrc_file."
        print_info "Please run 'source ~/.zshrc' or open a new terminal to use the alias."
    else
        print_info "Operation cancelled. No changes were made."
    fi
}

# Run the main function
main

exit 0 