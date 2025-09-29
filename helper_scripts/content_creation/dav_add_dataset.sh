#!/usr/bin/env bash
# set -x # Keep commented out unless actively debugging

# --- Load Shared Configuration ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
if [[ "$SCRIPT_DIR" == "." ]]; then
    SCRIPT_DIR=$(pwd)
fi

source "$SCRIPT_DIR/../common/dav_common.sh" || {
    echo "Error: Unable to source dav_common.sh"
    exit 1
}

# --- Initial Checks ---
check_dav_config || exit 1

# --- Script Information ---
SCRIPT_NAME="quarto-link-doc-creator"

# --- Shared Configuration File Details ---
DAV_CONFIG_DIR="$HOME/.config/dav"
DAV_CONFIG_FILE_NAME="settings.ini"
DAV_CONFIG_FILE_ABSOLUTE="" # Will be set by load_config_and_categories

# Keys used within DAV_CONFIG_FILE_NAME
KEY_DATASET_MANAGER_BASE_DIR="DATASET_MANAGER_BASE_DIRECTORY_PATH"
KEY_DATASET_DOCS_SUBDIR="DATASET_DOCUMENTS_SUBDIRECTORY"
KEY_DATA_PROJECT_BASE_DIR="DATA_PROJECT_BASE_DIR" # Used as delimiter for category parsing

# --- Global Variables for Resolved Paths ---
DATASET_MANAGER_BASE_DIR_ABSOLUTE=""
DATASET_DOCS_DIR_ABSOLUTE=""
DATASET_DOCS_SUBDIR_NAME="datasets" # Default value, can be overridden from config
QUARTO_PROJECT_DIR_ABSOLUTE=""

# --- Default Initial Categories ---
INITIAL_CATEGORIES=("technical" "article" "tutorial" "tool" "reference" "dataset")
CURRENT_CATEGORIES=()

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
        # Conditional newlines for better spacing in plain mode
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
    # Using a temporary variable for the heredoc content
    read -r -d '' help_text_content <<EOF
# $SCRIPT_NAME Help
**Usage:** \`$SCRIPT_NAME [-h]\`
Creates individual Quarto document files for each dataset, suitable for a Quarto listing page.

## Directory Structure
This script manages dataset documentation in a Quarto website structure:

1. **Configuration File:**
   - Location: \`$DAV_CONFIG_DIR/$DAV_CONFIG_FILE_NAME\`
   - This is where the script stores its settings

2. **Dataset Documentation Website:**
   - You choose a directory to be your Quarto website root
   - This is stored in config as: \`$KEY_DATASET_MANAGER_BASE_DIR\`
   - Example: \`/home/username/MyDatasetWebsite\`
   - Inside this directory, the script will create:
     - \`all-datasets.qmd\` (main listing page)
     - A subdirectory (default: 'datasets') containing all dataset .qmd files

## Configuration Settings
In \`$DAV_CONFIG_FILE_NAME\`:
- **Website Root Directory:**
  \`$KEY_DATASET_MANAGER_BASE_DIR=/path/to/your/website/root\`
  This is where your Quarto website will live. All dataset documentation will be stored here.

- **Dataset Files Subdirectory:**
  \`$KEY_DATASET_DOCS_SUBDIR=datasets\` (default if not set)
  This is the subdirectory where individual dataset .qmd files will be stored.

- **Categories:**
  Categories are listed as separate lines after the directory settings.

## Example Directory Structure
If you set \`$KEY_DATASET_MANAGER_BASE_DIR=/home/username/MyDatasetWebsite\`:
\`\`\`
/home/username/MyDatasetWebsite/          # Your Quarto website root
├── all-datasets.qmd                     # Main listing page
└── datasets/                            # Subdirectory for dataset files
    ├── climate-data-2023.qmd
    ├── population-stats.qmd
    └── ...
\`\`\`

## Options
  \`-h\`         Show this help message and exit.
EOF
    help_text="$help_text_content" # Assign to the variable
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
        # Basic normalization fallback
        local old_pwd; old_pwd=$(pwd)
        local dir_part; dir_part=$(dirname "$path_to_normalize")
        local file_part; file_part=$(basename "$path_to_normalize")
        
        if [[ ! -d "$dir_part" && -n "$dir_part" && "$dir_part" != "." ]]; then
             # This part is tricky: we shouldn't create directories during normalization
             # unless it's part of a setup step. For normalization, we assume valid existing paths mostly.
             # However, realpath -m can resolve non-existent paths.
             # Let's just try to cd and get pwd.
             : # Do nothing, let cd handle it
        fi

        if cd "$dir_part" &>/dev/null; then 
            normalized_output="$(pwd)/$file_part"
            cd "$old_pwd"
        else 
            normalized_output="$path_to_normalize" # Fallback if cd fails
        fi
    fi
    # Remove trailing slash unless it's the root "/"
    if [[ "$normalized_output" != "/" && "${normalized_output: -1}" == "/" ]]; then 
        normalized_output="${normalized_output%/}"
    fi
    echo "$normalized_output"
}

prompt_for_dir_interactive() {
    local description_text="$1"; local suggested_default_relative_to_home="$2"; local user_input normalized_user_path
    local full_suggested_default="$HOME/$suggested_default_relative_to_home"
    
    while true; do
        print_plain "$description_text (default: '$full_suggested_default')"
        if $GUM_AVAILABLE; then 
            user_input=$(gum input --value="$full_suggested_default" --placeholder="Enter path..." --width=80)
        else 
            read -r -p "> " user_input
        fi
        
        user_input=${user_input:-$full_suggested_default} # Use default if empty
        local user_input_trimmed; user_input_trimmed=$(echo "$user_input" | xargs) # Trim whitespace
        
        if [[ -z "$user_input_trimmed" ]]; then 
            print_warning "Path cannot be empty. Please try again."
            continue
        fi
        
        normalized_user_path=$(normalize_path_absolute "$user_input_trimmed")
        print_info "Path will be resolved to: $normalized_user_path"
        
        local confirm_path=true
        if $GUM_AVAILABLE; then 
            gum confirm "Use this path?" || confirm_path=false
        else 
            read -r -p "Use this path? [Y/n]: " c
            if [[ "$c" =~ ^[Nn]$ ]]; then confirm_path=false; fi
        fi
        
        if $confirm_path; then 
            echo "$normalized_user_path" # This is the stdout captured by the caller
            return 0
        fi
    done
}

load_config_and_categories() {
    local config_dir_abs; config_dir_abs=$(normalize_path_absolute "$DAV_CONFIG_DIR")
    DAV_CONFIG_FILE_ABSOLUTE="$config_dir_abs/$DAV_CONFIG_FILE_NAME"

    DATASET_DOCS_SUBDIR_NAME="datasets" # Initialize with default

    if [[ ! -f "$DAV_CONFIG_FILE_ABSOLUTE" ]]; then
        print_header "Welcome! Initial $SCRIPT_NAME Setup"
        print_warning "Configuration file not found: $DAV_CONFIG_FILE_ABSOLUTE"
        print_info "This script will help you set up a Quarto website for documenting datasets."
        print_info "You'll need to specify where this website should live on your system."
        
        DATASET_MANAGER_BASE_DIR_ABSOLUTE=$(prompt_for_dir_interactive "Enter the directory where your dataset documentation website should live (this will be your Quarto website root directory):" "MyDatasetWebsite")
        [[ -z "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" ]] && print_error "Website root directory setup failed. Exiting."
        
        # Verify the base directory
        if [[ ! -d "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" ]]; then
            local create_dir=false
            if $GUM_AVAILABLE; then 
                print_info "The website root directory '$DATASET_MANAGER_BASE_DIR_ABSOLUTE' doesn't exist yet."
                gum confirm "Create this directory now?" && create_dir=true
            else 
                print_info "The website root directory '$DATASET_MANAGER_BASE_DIR_ABSOLUTE' doesn't exist yet."
                read -r -p "Create this directory now? [Y/n]: " c
                if [[ ! "$c" =~ ^[Nn]$ ]]; then create_dir=true; fi
            fi
            if $create_dir; then 
                mkdir -p "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" || print_error "Failed to create website root directory '$DATASET_MANAGER_BASE_DIR_ABSOLUTE'. Exiting."
                print_success "Created website root directory: $DATASET_MANAGER_BASE_DIR_ABSOLUTE"
            else 
                print_error "Website root directory not created. Exiting."
            fi
        else
            # Directory exists, let's check its contents
            print_info "Checking existing directory structure..."
            
            # Check if it's a Quarto project
            if [[ -f "$DATASET_MANAGER_BASE_DIR_ABSOLUTE/_quarto.yml" ]]; then
                print_success "Found Quarto project configuration in this directory."
            else
                print_warning "No Quarto project configuration (_quarto.yml) found in this directory."
                if $GUM_AVAILABLE; then
                    if ! gum confirm "This directory doesn't appear to be a Quarto project. Continue anyway?"; then
                        print_error "Operation cancelled by user."
                        exit 1
                    fi
                else
                    read -r -p "This directory doesn't appear to be a Quarto project. Continue anyway? [y/N]: " c
                    if [[ ! "$c" =~ ^[Yy]$ ]]; then
                        print_error "Operation cancelled by user."
                        exit 1
                    fi
                fi
            fi

            # Check for existing datasets directory
            local default_docs_subdir_init="datasets"
            if [[ -d "$DATASET_MANAGER_BASE_DIR_ABSOLUTE/$default_docs_subdir_init" ]]; then
                print_warning "Found existing '$default_docs_subdir_init' directory in '$DATASET_MANAGER_BASE_DIR_ABSOLUTE'"
                print_info "This directory already contains:"
                ls -1 "$DATASET_MANAGER_BASE_DIR_ABSOLUTE/$default_docs_subdir_init" | while read -r item; do
                    print_info "  - $item"
                done
                
                if $GUM_AVAILABLE; then
                    if ! gum confirm "Use this existing '$default_docs_subdir_init' directory?"; then
                        print_info "You'll be prompted to choose a different subdirectory name."
                        default_docs_subdir_init="dataset_files"  # Change default to something else
                    fi
                else
                    read -r -p "Use this existing '$default_docs_subdir_init' directory? [Y/n]: " c
                    if [[ "$c" =~ ^[Nn]$ ]]; then
                        print_info "You'll be prompted to choose a different subdirectory name."
                        default_docs_subdir_init="dataset_files"  # Change default to something else
                    fi
                fi
            fi

            # Check for existing all-datasets.qmd
            if [[ -f "$DATASET_MANAGER_BASE_DIR_ABSOLUTE/all-datasets.qmd" ]]; then
                print_warning "Found existing 'all-datasets.qmd' in '$DATASET_MANAGER_BASE_DIR_ABSOLUTE'"
                if $GUM_AVAILABLE; then
                    if ! gum confirm "This file will be overwritten. Continue?"; then
                        print_error "Operation cancelled by user."
                        exit 1
                    fi
                else
                    read -r -p "This file will be overwritten. Continue? [y/N]: " c
                    if [[ ! "$c" =~ ^[Yy]$ ]]; then
                        print_error "Operation cancelled by user."
                        exit 1
                    fi
                fi
            fi
        fi

        print_info "Now, let's set up where the individual dataset files will be stored."
        print_info "These will be stored in a subdirectory of your website root."
        print_plain "Enter the name for the dataset files subdirectory (default: '$default_docs_subdir_init'):"
        local temp_subdir_input
        if $GUM_AVAILABLE; then 
            temp_subdir_input=$(gum input --value "$default_docs_subdir_init" --placeholder="e.g., datasets, data-docs, dataset-files")
        else 
            read -r -p "> " temp_subdir_input
        fi
        DATASET_DOCS_SUBDIR_NAME=${temp_subdir_input:-$default_docs_subdir_init}
        DATASET_DOCS_SUBDIR_NAME=$(echo "$DATASET_DOCS_SUBDIR_NAME" | xargs | tr -s ' /' '_' | sed 's/^_*//;s/_*$//') # Sanitize

        print_info "Your dataset documentation will be organized as follows:"
        print_info "Website Root: $DATASET_MANAGER_BASE_DIR_ABSOLUTE"
        print_info "Dataset Files: $DATASET_MANAGER_BASE_DIR_ABSOLUTE/$DATASET_DOCS_SUBDIR_NAME/"
        print_info "Main Listing: $DATASET_MANAGER_BASE_DIR_ABSOLUTE/all-datasets.qmd"

        mkdir -p "$config_dir_abs" || print_error "Could not create config directory: $config_dir_abs"
        
        local initial_dav_header="# Main DAV Configuration - $DAV_CONFIG_FILE_NAME\n\n"
        # Append if file exists but this section is new, otherwise create.
        if [ -f "$DAV_CONFIG_FILE_ABSOLUTE" ]; then initial_dav_header=""; fi

        {
            echo -n "$initial_dav_header" # Only if new file
            echo ""
            echo "# --- For $SCRIPT_NAME ---"
            echo "$KEY_DATASET_MANAGER_BASE_DIR=$DATASET_MANAGER_BASE_DIR_ABSOLUTE"
            echo "$KEY_DATASET_DOCS_SUBDIR=$DATASET_DOCS_SUBDIR_NAME"
            echo "# Categories for $SCRIPT_NAME (add one per line below):"
            printf "%s\n" "${INITIAL_CATEGORIES[@]}"
            echo "# --- End $SCRIPT_NAME Section ---"
            echo ""
        } >> "$DAV_CONFIG_FILE_ABSOLUTE"
        CURRENT_CATEGORIES=("${INITIAL_CATEGORIES[@]}")
        print_success "$SCRIPT_NAME configuration added to $DAV_CONFIG_FILE_ABSOLUTE"
    else # Config file exists, parse it
        local temp_lm_base_dir_val=""
        local temp_lm_docs_subdir_val=""
        local loaded_categories_temp=()
        local found_lm_base_dir_key=false
        local found_lm_docs_subdir_key=false # True if key found, or if we default & warn
        local reading_categories_now=false # Switched on after finding base dir (and ideally subdir key)

        while IFS= read -r line || [[ -n "$line" ]]; do
            local trimmed_line; trimmed_line="${line#"${line%%[![:space:]]*}"}"; trimmed_line="${trimmed_line%"${trimmed_line##*[![:space:]]}"}" # Trim whitespace

            if [[ -z "$trimmed_line" || "$trimmed_line" == \#* ]]; then # Skip empty or comment lines
                # Special handling for end-of-section comments within our section
                if $reading_categories_now && \
                   ( [[ "$trimmed_line" == *"--- End $SCRIPT_NAME Section ---"* ]] || \
                     ( [[ "$trimmed_line" == *"--- For "* ]] && [[ "$trimmed_line" != *"--- For $SCRIPT_NAME"* ]] ) || \
                     [[ "$trimmed_line" == ${KEY_DATA_PROJECT_BASE_DIR}=* ]] \
                   ); then
                    reading_categories_now=false # Stop reading categories
                fi
                continue
            fi

            if ! $found_lm_base_dir_key && [[ "$trimmed_line" == ${KEY_DATASET_MANAGER_BASE_DIR}=* ]]; then
                temp_lm_base_dir_val=$(echo "$trimmed_line" | cut -d'=' -f2- | xargs)
                DATASET_MANAGER_BASE_DIR_ABSOLUTE=$(normalize_path_absolute "$temp_lm_base_dir_val")
                found_lm_base_dir_key=true
                # If docs subdir key hasn't been found, we assume categories might follow directly or after subdir key
                if ! $found_lm_docs_subdir_key; then reading_categories_now=true; fi 
                continue
            fi

            if $found_lm_base_dir_key && ! $found_lm_docs_subdir_key && [[ "$trimmed_line" == ${KEY_DATASET_DOCS_SUBDIR}=* ]]; then
                temp_lm_docs_subdir_val=$(echo "$trimmed_line" | cut -d'=' -f2- | xargs)
                DATASET_DOCS_SUBDIR_NAME="$temp_lm_docs_subdir_val" # This might override default
                found_lm_docs_subdir_key=true
                reading_categories_now=true # Definitely start reading categories now
                continue
            fi
            
            if $reading_categories_now; then
                # Delimiters that stop category reading
                if [[ "$trimmed_line" == ${KEY_DATA_PROJECT_BASE_DIR}=* ]] || \
                   ( [[ "$trimmed_line" == *"--- For "* ]] && [[ "$trimmed_line" != *"--- For $SCRIPT_NAME"* ]] ) || \
                   [[ "$trimmed_line" == *"--- End $SCRIPT_NAME Section --"* ]] ; then
                    reading_categories_now=false
                else
                    # It's a category
                    loaded_categories_temp+=("$trimmed_line")
                fi
            fi
        done < "$DAV_CONFIG_FILE_ABSOLUTE"

        if ! $found_lm_base_dir_key; then
            print_warning "$KEY_DATASET_MANAGER_BASE_DIR not found in $DAV_CONFIG_FILE_ABSOLUTE."
            print_info "Let's set up your dataset documentation website location."
            print_info "This will be the root directory for your Quarto website where all dataset documentation will live."
            
            DATASET_MANAGER_BASE_DIR_ABSOLUTE=$(prompt_for_dir_interactive "Enter the directory where your dataset documentation website should live (this will be your Quarto website root directory):" "MyDatasetWebsite")
            [[ -z "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" ]] && print_error "Website root directory setup failed."
            
            if [[ ! -d "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" ]]; then 
                print_info "The website root directory '$DATASET_MANAGER_BASE_DIR_ABSOLUTE' doesn't exist yet."
                if gum confirm "Create this directory now?"; then 
                    mkdir -p "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" || print_error "Failed to create website root directory"
                    print_success "Created website root directory: $DATASET_MANAGER_BASE_DIR_ABSOLUTE"
                else 
                    print_error "Website root directory not created."
                fi
            fi

            print_info "Now, let's set up where the individual dataset files will be stored."
            print_info "These will be stored in a subdirectory of your website root."
            local default_docs_subdir_append="datasets"
            if $GUM_AVAILABLE; then 
                temp_lm_docs_subdir_val=$(gum input --value "$default_docs_subdir_append" --placeholder "Enter name for dataset files subdirectory:")
            else 
                read -r -p "Enter name for dataset files subdirectory (default: '$default_docs_subdir_append'): " temp_lm_docs_subdir_val
            fi
            DATASET_DOCS_SUBDIR_NAME=${temp_lm_docs_subdir_val:-$default_docs_subdir_append}
            DATASET_DOCS_SUBDIR_NAME=$(echo "$DATASET_DOCS_SUBDIR_NAME" | xargs | tr -s ' /' '_' | sed 's/^_*//;s/_*$//')

            print_info "Your dataset documentation will be organized as follows:"
            print_info "Website Root: $DATASET_MANAGER_BASE_DIR_ABSOLUTE"
            print_info "Dataset Files: $DATASET_MANAGER_BASE_DIR_ABSOLUTE/$DATASET_DOCS_SUBDIR_NAME/"
            print_info "Main Listing: $DATASET_MANAGER_BASE_DIR_ABSOLUTE/all-datasets.qmd"

            { echo ""; echo "# --- For $SCRIPT_NAME ---"; echo "$KEY_DATASET_MANAGER_BASE_DIR=$DATASET_MANAGER_BASE_DIR_ABSOLUTE"; echo "$KEY_DATASET_DOCS_SUBDIR=$DATASET_DOCS_SUBDIR_NAME";
              echo "# Categories for $SCRIPT_NAME (add one per line below):"; printf "%s\n" "${INITIAL_CATEGORIES[@]}"; echo "# --- End $SCRIPT_NAME Section ---"; echo ""; 
            } >> "$DAV_CONFIG_FILE_ABSOLUTE"
            CURRENT_CATEGORIES=("${INITIAL_CATEGORIES[@]}")
            print_success "$SCRIPT_NAME section appended to $DAV_CONFIG_FILE_ABSOLUTE"
            found_lm_base_dir_key=true; found_lm_docs_subdir_key=true # Assume these are now set
        fi

        if [[ ! -d "$DATASET_MANAGER_BASE_DIR_ABSOLUTE" ]]; then print_error "Base Directory '$DATASET_MANAGER_BASE_DIR_ABSOLUTE' (from config or prompt) is invalid or not found."; fi
        
        if ! $found_lm_docs_subdir_key && $found_lm_base_dir_key; then # Base dir was found, but not subdir key explicitly
            # DATASET_DOCS_SUBDIR_NAME retains its initialized default "link_docs"
            print_warning "$KEY_DATASET_DOCS_SUBDIR key not found. Using default subdir '$DATASET_DOCS_SUBDIR_NAME'."
            # We don't set found_lm_docs_subdir_key to true here, as it wasn't *found*, just defaulted.
        fi
        
        if [ ${#loaded_categories_temp[@]} -eq 0 ] && $found_lm_base_dir_key; then
            print_warning "No categories for $SCRIPT_NAME found in config. Using defaults."
            CURRENT_CATEGORIES=("${INITIAL_CATEGORIES[@]}")
            print_info "You can add categories manually to '$DAV_CONFIG_FILE_ABSOLUTE' under the $SCRIPT_NAME section."
        elif $found_lm_base_dir_key; then
            CURRENT_CATEGORIES=($(printf "%s\n" "${loaded_categories_temp[@]}" | sort -u))
        fi
    fi

    DATASET_DOCS_SUBDIR_NAME=$(echo "$DATASET_DOCS_SUBDIR_NAME" | tr -s ' /' '_' | sed 's/^_*//;s/_*$//') # Final sanitize
    if [[ -z "$DATASET_DOCS_SUBDIR_NAME" ]]; then DATASET_DOCS_SUBDIR_NAME="datasets"; fi # Ensure not empty

    DATASET_DOCS_DIR_ABSOLUTE="$DATASET_MANAGER_BASE_DIR_ABSOLUTE/$DATASET_DOCS_SUBDIR_NAME"
    QUARTO_PROJECT_DIR_ABSOLUTE="$DATASET_MANAGER_BASE_DIR_ABSOLUTE"

    print_info "Dataset System Base Dir: $DATASET_MANAGER_BASE_DIR_ABSOLUTE"
    print_info "Dataset Documents Subdir: $DATASET_DOCS_SUBDIR_NAME (-> $DATASET_DOCS_DIR_ABSOLUTE)"
    print_info "${#CURRENT_CATEGORIES[@]} categories loaded."
    print_info "Quarto Project Dir for rendering: $QUARTO_PROJECT_DIR_ABSOLUTE"
}

save_new_category_to_dav_config() {
    local new_category="$1"
    local category_exists_in_memory=false
    for cat_mem in "${CURRENT_CATEGORIES[@]}"; do
        if [[ "$cat_mem" == "$new_category" ]]; then category_exists_in_memory=true; break; fi
    done
    if $category_exists_in_memory; then print_info "Category '$new_category' is already known."; return 0; fi

    print_info "Adding new category '$new_category' to shared config file: $DAV_CONFIG_FILE_ABSOLUTE"
    
    local temp_config_file; temp_config_file=$(mktemp) || print_error "Failed to create temporary file for config update."
    
    local in_script_section=false
    local categories_header_found=false
    local new_category_written=false
    local end_section_marker_found=false

    local script_section_start_marker="# --- For $SCRIPT_NAME ---"
    local categories_header_text="# Categories for $SCRIPT_NAME (add one per line below):"
    local script_section_end_marker="# --- End $SCRIPT_NAME Section ---"

    # Read the existing config file and write to temp file
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$script_section_start_marker" ]]; then
            in_script_section=true
        fi

        if $in_script_section && ! $new_category_written; then
            if [[ "$line" == "$categories_header_text" ]]; then
                categories_header_found=true
                echo "$line" >> "$temp_config_file" # Write the header
                echo "$new_category" >> "$temp_config_file" # Write the new category immediately after
                new_category_written=true
                continue # Skip original line echo for this iteration
            elif $categories_header_found && ( [[ "$line" == $script_section_end_marker* ]] || \
                                             [[ "$line" == ${KEY_DATA_PROJECT_BASE_DIR}=* ]] || \
                                             ( [[ "$line" == *"--- For "* ]] && [[ "$line" != "$script_section_start_marker"* ]] ) ); then
                # We are at the end of category list or section, and header was found
                echo "$new_category" >> "$temp_config_file" # Write new category before this delimiter
                new_category_written=true
            fi
        fi
         echo "$line" >> "$temp_config_file" # Write current line

        if $in_script_section && [[ "$line" == $script_section_end_marker* ]] ; then
            end_section_marker_found=true
            if ! $new_category_written; then # If section ended and category still not written (e.g. no category header)
                # This implies we should have inserted it before the end marker,
                # but if the above logic failed, this is a last attempt.
                # A more robust solution would be to buffer lines and insert precisely.
                # For now, if it's not written, it means the config structure might be unusual.
                # Let's assume it must be written if categories_header_found was true.
                # This part of the logic is tricky; the original script had complex insertion.
                # A simpler approach for now: if categories_header_found and not written, it's an issue.
                # If !categories_header_found, it implies the section is malformed for categories.
                 print_warning "Could not automatically find the perfect spot for '$new_category' if '$categories_header_text' was missing or section ended abruptly."
            fi
            in_script_section=false # No longer in our script's section
        fi
    done < "$DAV_CONFIG_FILE_ABSOLUTE"

    if ! $new_category_written; then
        # This case means the script section was not found, or category header was not found,
        # or some other edge case. Safest is to append it to the script's section if we can find it,
        # or append a new section if the script's section itself is missing.
        # This part is complex and error-prone. The original script attempted a specific insertion.
        # For this rewrite, if the specific insertion points aren't met, we'll warn.
        # A robust version would re-create the section if needed.
        print_warning "Failed to insert new category '$new_category' automatically. Section markers might be missing or malformed in $DAV_CONFIG_FILE_ABSOLUTE."
        print_info "Please add '$new_category' manually under the '$SCRIPT_NAME' section."
        rm "$temp_config_file"
        return 1 # Indicate failure to save automatically
    fi

    if $new_category_written; then
        if mv "$temp_config_file" "$DAV_CONFIG_FILE_ABSOLUTE"; then
            print_info "Category '$new_category' saved to $DAV_CONFIG_FILE_ABSOLUTE."
            CURRENT_CATEGORIES+=("$new_category")
            CURRENT_CATEGORIES=($(printf "%s\n" "${CURRENT_CATEGORIES[@]}" | sort -u))
        else
            print_error "Failed to update config file '$DAV_CONFIG_FILE_ABSOLUTE' with new category."
            rm "$temp_config_file"
            return 1
        fi
    else
        # This else should ideally not be reached if the above logic is sound.
        print_warning "Category '$new_category' was not written for an unknown reason."
        rm "$temp_config_file"
        return 1
    fi
    return 0
}

create_or_update_main_listing_qmd() {
    print_info "Attempting to create/update main listing file (all-datasets.qmd)..."
    local main_listing_filename="all-datasets.qmd"
    local main_listing_filepath="$QUARTO_PROJECT_DIR_ABSOLUTE/$main_listing_filename"
    
    if [[ -z "$QUARTO_PROJECT_DIR_ABSOLUTE" ]]; then
        print_warning "Quarto project directory is not set. Cannot create main listing file."
        return 1
    fi
    if [[ -z "$DATASET_DOCS_SUBDIR_NAME" ]]; then
        print_warning "Dataset documents subdirectory name is not set. Cannot create main listing file."
        return 1
    fi

    local listing_contents_path="$DATASET_DOCS_SUBDIR_NAME/*.qmd"

    {
        echo "---"
        echo "title: \"Datasets Collection\""
        echo "listing:"
        echo "  contents: $DATASET_DOCS_SUBDIR_NAME"
        echo "  type: default"
        echo "  sort: \"date desc\""
        echo "  sort-ui: [title, date, author]"
        echo "  filter-ui: [title, date, author, categories, description]"
        echo "  fields: [date, title, author, description, categories, image]"
        echo "  page-size: 25"
        echo "---" 
        echo ""
        echo "<!--"
        echo "This page lists all dataset documents from the '$DATASET_DOCS_SUBDIR_NAME' directory."
        echo "It is automatically generated/updated by the $SCRIPT_NAME script."
        echo "-->"
    } > "$main_listing_filepath"

    if [ $? -eq 0 ]; then
        print_success "Main listing file created/updated: $main_listing_filepath"
        print_info "You can include this file in your Quarto project's navigation or link to it directly."
    else
        print_warning "Failed to create/update main listing file: $main_listing_filepath"
        return 1
    fi
    return 0
}

# --- Argument Parsing ---
while getopts ":h" opt; do
  case "$opt" in # Quote "$opt" for robustness
    h)
      show_help # show_help calls exit
      ;;
    \?)
      print_error "Invalid option: -$OPTARG. Use -h for help."
      # print_error calls exit
      ;;
    :) # Handle missing arguments for options that require them (none in this script's getopts string)
      print_error "Option -$OPTARG requires an argument, but getopts string is not configured for it."
      # print_error calls exit
      ;;
  esac
done
shift $((OPTIND-1)) # Remove processed options


# --- Main Script Logic ---
main() {
    print_header "$SCRIPT_NAME Initializing" "Quarto Document Listing Mode"
    
    # Check for config file existence first
    check_dav_config || exit 1
    
    load_config_and_categories

    # Create dataset docs directory if it doesn't exist
    if [[ ! -d "$DATASET_DOCS_DIR_ABSOLUTE" ]]; then
        print_info "Dataset documents directory '$DATASET_DOCS_DIR_ABSOLUTE' does not exist. Creating it..."
        mkdir -p "$DATASET_DOCS_DIR_ABSOLUTE" || print_error "Failed to create dataset documents directory: $DATASET_DOCS_DIR_ABSOLUTE"
    fi


    print_header "Step 1: Dataset Details"
    local DATASET_URL_RAW DATASET_URL
    print_plain "URL of the dataset:"
    if $GUM_AVAILABLE; then DATASET_URL_RAW=$(gum input --placeholder="https://example.com" --width=80)
    else read -r -p "> " DATASET_URL_RAW; fi
    DATASET_URL=$(echo "$DATASET_URL_RAW" | xargs)
    if [[ -z "$DATASET_URL" ]]; then print_error "URL cannot be empty."; fi
    if ! [[ "$DATASET_URL" =~ ^https?:// ]]; then 
        print_warning "URL does not start with http(s)://."
        local continue_anyway=false
        if $GUM_AVAILABLE; then gum confirm "Continue with this URL?" && continue_anyway=true
        else read -r -p "Continue with this URL? [Y/n]: " c; if [[ ! "$c" =~ ^[Nn]$ ]]; then continue_anyway=true; fi; fi
        if ! $continue_anyway; then print_error "Operation cancelled by user."; fi
    fi

    local TEMP_URL_FOR_TITLE SUGGESTED_TITLE DATASET_TITLE_RAW DATASET_TITLE
    TEMP_URL_FOR_TITLE=$(echo "$DATASET_URL" | sed -e 's|https\?://||' -e 's|www\.||' -e 's|/$||')
    local LAST_PART; LAST_PART=$(echo "$TEMP_URL_FOR_TITLE" | sed -e 's|.*/||' -e 's|[?#].*||')
    if [[ -z "$LAST_PART" || "$LAST_PART" == "$TEMP_URL_FOR_TITLE" ]]; then 
        LAST_PART=$(echo "$TEMP_URL_FOR_TITLE" | cut -d'/' -f1 | cut -d'?' -f1 | cut -d'#' -f1)
    fi
    SUGGESTED_TITLE=$(echo "$LAST_PART" | sed -e 's/[._-]/ /g' -e 's/\+/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print $0}')
    if [[ -z "$SUGGESTED_TITLE" ]]; then SUGGESTED_TITLE="New Dataset"; fi
    
    print_plain "Title for this dataset document (default: '$SUGGESTED_TITLE'):"
    if $GUM_AVAILABLE; then DATASET_TITLE_RAW=$(gum input --value="$SUGGESTED_TITLE" --placeholder="Enter title..." --width=80)
    else read -r -p "> " r_t; DATASET_TITLE_RAW="$r_t"; fi # No direct default in read, user hits enter
    DATASET_TITLE=${DATASET_TITLE_RAW:-$SUGGESTED_TITLE} # Apply default if input was empty
    DATASET_TITLE=$(echo "$DATASET_TITLE" | xargs)
    if [[ -z "$DATASET_TITLE" ]]; then print_error "Title cannot be empty."; fi

    local DATASET_DESCRIPTION_RAW DATASET_DESCRIPTION
    print_plain "Brief description (optional, Ctrl+D or empty line then Enter to finish for plain input):"
    if $GUM_AVAILABLE; then DATASET_DESCRIPTION_RAW=$(gum write --placeholder="Enter description...")
    else DATASET_DESCRIPTION_RAW=$(cat); fi # Read multiple lines until EOF (Ctrl+D)
    DATASET_DESCRIPTION=$(echo "$DATASET_DESCRIPTION_RAW" | xargs) # Trim leading/trailing whitespace, squashes internal newlines

    print_header "Step 2: Select Categories"
    local CATEGORIES_WITH_OTHER=("${CURRENT_CATEGORIES[@]}" "Other...")
    local SELECTED_CATEGORIES_RAW
    
    if $GUM_AVAILABLE; then 
        SELECTED_CATEGORIES_RAW=$(gum choose "${CATEGORIES_WITH_OTHER[@]}" --no-limit --height=$((${#CATEGORIES_WITH_OTHER[@]} + 2)) --cursor="> " --header="Select categories (space to select, enter to confirm):")
    else 
        print_plain "Available categories (select one or type new, then Enter):"
        local i=1
        for item in "${CATEGORIES_WITH_OTHER[@]}"; do echo "  $i) $item" >&2; i=$((i+1)); done
        read -r -p "Choice (number or new category name): " choice_input
        if [[ "$choice_input" =~ ^[0-9]+$ ]] && [ "$choice_input" -ge 1 ] && [ "$choice_input" -le ${#CATEGORIES_WITH_OTHER[@]} ]; then 
            SELECTED_CATEGORIES_RAW="${CATEGORIES_WITH_OTHER[$((choice_input-1))]}"
        elif [[ -n "$choice_input" ]]; then # User typed a category name
            SELECTED_CATEGORIES_RAW="$choice_input" # Treat as a single new/existing category
        else
            print_warning "No category selected or entered."
            SELECTED_CATEGORIES_RAW=""
        fi
    fi

    local FINAL_CATEGORIES_ARRAY=()
    local NEW_CATEGORIES_TO_SAVE=() # Categories that are new AND need saving
    local new_category_added_flag=false

    local IFS=$'\n' # Process gum choose output line by line
    for selected_item_raw in $SELECTED_CATEGORIES_RAW; do
        local selected_item; selected_item=$(echo "$selected_item_raw" | xargs) # Trim each selected item
        if [[ -z "$selected_item" ]]; then continue; fi

        if [[ "$selected_item" == "Other..." ]]; then
            local CUSTOM_CATEGORY_RAW CUSTOM_CATEGORY_TEMP new_custom_category
            print_plain "Enter new category name:"
            if $GUM_AVAILABLE; then CUSTOM_CATEGORY_RAW=$(gum input --placeholder="New category...")
            else read -r -p "> " CUSTOM_CATEGORY_RAW; fi
            CUSTOM_CATEGORY_TEMP=$(echo "$CUSTOM_CATEGORY_RAW" | xargs)
            if [[ -z "$CUSTOM_CATEGORY_TEMP" ]]; then print_warning "Custom category name was empty. Skipping."; continue; fi
            
            new_custom_category=$(echo "$CUSTOM_CATEGORY_TEMP" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]_' '_') # Sanitize
            if [[ -z "$new_custom_category" ]]; then print_warning "Sanitized custom category was empty. Skipping."; continue; fi
            
            # Add to final list if not already there
            local is_in_final=false
            for fc_item in "${FINAL_CATEGORIES_ARRAY[@]}"; do if [[ "$fc_item" == "$new_custom_category" ]]; then is_in_final=true; break; fi; done
            if ! $is_in_final; then FINAL_CATEGORIES_ARRAY+=("$new_custom_category"); fi
            
            # Check if it's new compared to CURRENT_CATEGORIES
            local is_in_current=false
            for cc_item in "${CURRENT_CATEGORIES[@]}"; do if [[ "$cc_item" == "$new_custom_category" ]]; then is_in_current=true; break; fi; done
            if ! $is_in_current; then 
                # Also check if it's already staged for saving
                local is_in_new_to_save=false
                for ncts_item in "${NEW_CATEGORIES_TO_SAVE[@]}"; do if [[ "$ncts_item" == "$new_custom_category" ]]; then is_in_new_to_save=true; break; fi; done
                if ! $is_in_new_to_save; then NEW_CATEGORIES_TO_SAVE+=("$new_custom_category"); fi
            fi
            new_category_added_flag=true # Mark that we processed a new category input
        else
            # Add to final list if not already there
            local is_in_final=false
            for fc_item in "${FINAL_CATEGORIES_ARRAY[@]}"; do if [[ "$fc_item" == "$selected_item" ]]; then is_in_final=true; break; fi; done
            if ! $is_in_final; then FINAL_CATEGORIES_ARRAY+=("$selected_item"); fi
        fi
    done
    unset IFS # Reset IFS

    if [ ${#NEW_CATEGORIES_TO_SAVE[@]} -gt 0 ]; then
        print_info "Attempting to save ${#NEW_CATEGORIES_TO_SAVE[@]} new category/categories to config..."
        for new_cat_to_save in "${NEW_CATEGORIES_TO_SAVE[@]}"; do
            save_new_category_to_dav_config "$new_cat_to_save" # This function will update CURRENT_CATEGORIES
        done
    elif $new_category_added_flag && [ ${#NEW_CATEGORIES_TO_SAVE[@]} -eq 0 ]; then
        print_info "The new category entered already exists or was not saved."
    fi
    
    if [ ${#FINAL_CATEGORIES_ARRAY[@]} -eq 0 ]; then print_warning "No categories will be assigned to this dataset."; fi

    print_header "Step 3: Create Dataset Document"
    local SANITIZED_TITLE NEW_QMD_FILENAME NEW_QMD_FILE_PATH
    SANITIZED_TITLE=$(echo "$DATASET_TITLE" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-*//' -e 's/-*$//')
    if [[ -z "$SANITIZED_TITLE" ]]; then SANITIZED_TITLE="untitled-dataset"; fi
    NEW_QMD_FILENAME="${SANITIZED_TITLE}.qmd"
    NEW_QMD_FILE_PATH="$DATASET_DOCS_DIR_ABSOLUTE/$NEW_QMD_FILENAME"

    if [[ -f "$NEW_QMD_FILE_PATH" ]]; then 
        print_warning "File '$NEW_QMD_FILE_PATH' already exists. It will be overwritten."
        # Add a confirmation step if you prefer not to overwrite automatically
        # For example, using gum confirm or read -p
    fi

    local YAML_CATEGORIES="["
    local first_cat=true
    for cat_item in "${FINAL_CATEGORIES_ARRAY[@]}"; do
        if ! $first_cat; then YAML_CATEGORIES+=", "; fi
        YAML_CATEGORIES+="\"$cat_item\""
        first_cat=false
    done
    YAML_CATEGORIES+="]"
    if [[ "$YAML_CATEGORIES" == "[]" ]]; then YAML_CATEGORIES=""; fi # Empty string if no categories

    # Prepare description for YAML: escape double quotes, handle multi-line if needed (though xargs squashed it)
    # For simple YAML, just escaping quotes is often enough for a single-line description.
    local ESCAPED_DESCRIPTION; ESCAPED_DESCRIPTION=$(echo "$DATASET_DESCRIPTION" | sed 's/"/\\"/g')

    # Create the .qmd file content
    # Using a mix of echo for separators and printf for content lines
    echo "---" > "$NEW_QMD_FILE_PATH"
    printf "title: \"%s\"\n" "$DATASET_TITLE" >> "$NEW_QMD_FILE_PATH"
    printf "date: \"%s\"\n" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "$NEW_QMD_FILE_PATH"
    if [[ -n "$DATASET_DESCRIPTION" ]]; then printf "description: \"%s\"\n" "$ESCAPED_DESCRIPTION" >> "$NEW_QMD_FILE_PATH"; fi
    if [[ -n "$YAML_CATEGORIES" ]]; then printf "categories: %s\n" "$YAML_CATEGORIES" >> "$NEW_QMD_FILE_PATH"; fi
    printf "dataset-url: \"%s\"\n" "$DATASET_URL" >> "$NEW_QMD_FILE_PATH"
    printf "format: html\n" >> "$NEW_QMD_FILE_PATH" # Assuming default format
    echo "---" >> "$NEW_QMD_FILE_PATH" # End YAML frontmatter
    echo "" >> "$NEW_QMD_FILE_PATH" # Extra newline after frontmatter
    printf "## [%s](%s)\n\n" "$DATASET_TITLE" "$DATASET_URL" >> "$NEW_QMD_FILE_PATH" # Top H2 link

    # Description section
    if [[ -n "$DATASET_DESCRIPTION" ]]; then
        printf "## Description\n\n" >> "$NEW_QMD_FILE_PATH"
        printf "%s\n\n" "$DATASET_DESCRIPTION" >> "$NEW_QMD_FILE_PATH"
    fi

    # Getting Data section
    printf "## Getting Data\n\n" >> "$NEW_QMD_FILE_PATH"

    if [ $? -eq 0 ]; then 
        print_success "New dataset document created: $NEW_QMD_FILE_PATH"
        if [ ${#NEW_CATEGORIES_TO_SAVE[@]} -gt 0 ]; then
             print_info "Note: New categorie(s) '${NEW_CATEGORIES_TO_SAVE[*]}' were processed for the configuration file."
        fi
        # Attempt to create/update the main listing file
        create_or_update_main_listing_qmd
    else 
        print_error "Failed to create dataset document: $NEW_QMD_FILE_PATH"
    fi

    local QUARTO_MISSING=true
    if command -v quarto &> /dev/null; then QUARTO_MISSING=false; fi

    if ! $QUARTO_MISSING; then
        print_header "Step 4: Render Quarto Project (Optional)"
        if [[ ! -d "$QUARTO_PROJECT_DIR_ABSOLUTE" ]]; then 
            print_warning "Quarto Project Directory '$QUARTO_PROJECT_DIR_ABSOLUTE' (derived from Dataset System Base Dir) not found. Skipping render option."
        else
            local do_render=false
            if $GUM_AVAILABLE; then 
                if gum confirm "Render Quarto project in '$QUARTO_PROJECT_DIR_ABSOLUTE' now?"; then do_render=true; fi
            else 
                read -r -p "Render Quarto project in '$QUARTO_PROJECT_DIR_ABSOLUTE' now? [y/N]: " c
                if [[ "$c" =~ ^[Yy]$ ]]; then do_render=true; fi
            fi
            
            if $do_render; then 
                print_info "Rendering Quarto project '$QUARTO_PROJECT_DIR_ABSOLUTE'..."
                if $GUM_AVAILABLE; then 
                    gum spin --show-output --spinner="dot" --title="Rendering Quarto project..." -- quarto render "$QUARTO_PROJECT_DIR_ABSOLUTE"
                else 
                    quarto render "$QUARTO_PROJECT_DIR_ABSOLUTE"
                fi
                local RENDER_EXIT_CODE=$?
                if [ $RENDER_EXIT_CODE -ne 0 ]; then 
                    print_warning "Quarto render command finished with errors (Exit Code: $RENDER_EXIT_CODE)."
                else 
                    print_success "Quarto project rendered successfully."
                fi
            else
                print_info "Skipping Quarto project rendering."
            fi
        fi
    else 
        print_warning "Skipping Quarto render option: 'quarto' command not found in PATH."
    fi
    
    print_header "($SCRIPT_NAME) All operations complete."
}

# Run the main function
main

exit 0