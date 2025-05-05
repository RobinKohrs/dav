#!/bin/bash

# This script expects a configuration file named 'wiki_conf'
# located in the parent directory (../wiki relative to this script).
# This config file MUST contain a line like:
# LINK_TXT_LOCATION="/path/to/your/keywords.txt"

# --- Determine Paths Relative to the Script ---
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
WIKI_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

# --- Configuration File Path ---
CONFIG_FILE="$WIKI_DIR/wiki_conf" # <--- RENAMED HERE
KEYWORDS_FILE=""

# --- Default Project Paths (relative to WIKI_DIR) ---
TARGET_QMD_FILE="$WIKI_DIR/links.qmd"
QUARTO_PROJECT_DIR="$WIKI_DIR"

# --- Default Keywords (used only if keyword file is created) ---
INITIAL_KEYWORDS=(
	"qgis" "r" "automation"
)

# --- Basic Helper Functions (No gum style/format) ---
print_error() {
  echo "" >&2
  echo "*** ERROR: $1 ***" >&2
  echo "" >&2
  exit 1
}

print_success() {
    echo ""
    echo "+++ SUCCESS: $1 +++"
    if [ -n "$2" ]; then echo "    $2"; fi
    echo ""
}

print_warning() {
    echo "!!! WARNING: $1 !!!" >&2
}

# --- Dependency Check (Basic) ---
GUM_AVAILABLE=false
if command -v gum &> /dev/null; then GUM_AVAILABLE=true; fi

# --- Load Configuration and Keywords ---
load_config_and_keywords() {
    echo "- Looking for configuration in: $CONFIG_FILE" # Uses the updated variable

    # 1. Check if Config File Exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Updated error message
        print_error "Configuration file not found at '$CONFIG_FILE'. Please create it and add the 'LINK_TXT_LOCATION' variable."
    fi

    # 2. Read LINK_TXT_LOCATION from Config File
    local raw_path
    raw_path=$(grep -m 1 '^LINK_TXT_LOCATION=' "$CONFIG_FILE" | cut -d'=' -f2-) # Reads from the updated CONFIG_FILE path

    if [[ -z "$raw_path" ]]; then
         # Updated error message
         print_error "The variable 'LINK_TXT_LOCATION' is not defined or is empty in '$CONFIG_FILE'."
    fi

    # ... (rest of path processing, validation, keyword loading remains the same) ...
    local path_no_quotes
    path_no_quotes=$(echo "$raw_path" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    if [[ "$path_no_quotes" == /* ]] || [[ "$path_no_quotes" == ~* ]]; then
        KEYWORDS_FILE="${path_no_quotes/#\~/$HOME}"
    else
        KEYWORDS_FILE="$WIKI_DIR/$path_no_quotes"
        KEYWORDS_FILE=$(cd "$(dirname "$KEYWORDS_FILE")" && pwd)/$(basename "$KEYWORDS_FILE")
    fi
    printf -- "- Keywords file location set to: %s\n" "$KEYWORDS_FILE"
    local KEYWORDS_DIR
    KEYWORDS_DIR=$(dirname "$KEYWORDS_FILE")
     if [[ ! -d "$KEYWORDS_DIR" ]]; then print_error "The directory '$KEYWORDS_DIR' (for keywords file) does not exist. Please create it."; fi
    if [[ ! -f "$KEYWORDS_FILE" ]]; then
        printf -- "- Keywords file '%s' not found.\n" "$KEYWORDS_FILE"
        local create_kw_file=false
        if $GUM_AVAILABLE; then if gum confirm "Create keywords file '$KEYWORDS_FILE' with defaults?"; then create_kw_file=true; fi; else
             read -p "Create keywords file '$KEYWORDS_FILE' with defaults? [Y/n]: " confirm_create_kw; if [[ ! "$confirm_create_kw" =~ ^[Nn]$ ]]; then create_kw_file=true; fi
        fi
        if $create_kw_file; then printf "%s\n" "${INITIAL_KEYWORDS[@]}" > "$KEYWORDS_FILE" || print_error "Failed to create keywords file '$KEYWORDS_FILE'."; printf -- "- Created keyword file with defaults.\n"; CURRENT_KEYWORDS=("${INITIAL_KEYWORDS[@]}"); else print_error "Keyword file required but not created. Aborting."; fi
    else
        mapfile -t loaded_keywords < <(grep . "$KEYWORDS_FILE") || print_error "Failed to read keywords from '$KEYWORDS_FILE'."
        if [ ${#loaded_keywords[@]} -eq 0 ] && [ -s "$KEYWORDS_FILE" ]; then print_error "Failed to parse keywords from '$KEYWORDS_FILE'."; elif [ ${#loaded_keywords[@]} -eq 0 ]; then print_warning "Keywords file '$KEYWORDS_FILE' is empty. Using defaults."; CURRENT_KEYWORDS=("${INITIAL_KEYWORDS[@]}"); else CURRENT_KEYWORDS=($(printf "%s\n" "${loaded_keywords[@]}" | sort -u)); printf -- "- Loaded %d unique keywords.\n" "${#CURRENT_KEYWORDS[@]}"; fi
    fi
}

# Function to save a new keyword to the file
save_new_keyword() {
    local new_keyword="$1"
    if ! grep -Fxq "$new_keyword" "$KEYWORDS_FILE"; then
        printf -- "- Adding new keyword '%s' to '%s'.\n" "$new_keyword" "$KEYWORDS_FILE"
        echo "$new_keyword" >> "$KEYWORDS_FILE" || print_warning "Failed to append new keyword to '$KEYWORDS_FILE'."
    else
         printf -- "- Keyword '%s' already exists.\n" "$new_keyword"
    fi
}


# --- Main Script ---

echo "Starting add_link.sh script..."

# Load configuration (will use wiki_conf now) and keywords
load_config_and_keywords

# --- Proceed with Gum/Basic Prompts ---
# The rest of the script (Steps 1-7) remains exactly the same as the previous version.
# It uses the $KEYWORDS_FILE variable which was set correctly by load_config_and_keywords.

# 1. Get the URL
echo ""; echo "--- Step 1: Enter URL ---"
if $GUM_AVAILABLE; then LINK_URL=$(gum input --placeholder "Paste or type the URL..."); else read -p "URL: " LINK_URL; fi
if [[ -z "$LINK_URL" ]]; then print_error "URL cannot be empty."; fi
if ! [[ "$LINK_URL" =~ ^https?:// ]]; then
     print_warning "URL does not start with http:// or https://."
     if $GUM_AVAILABLE; then gum confirm "Continue anyway?" || print_error "Operation cancelled."; else read -p "Continue anyway? [y/N]: " confirm_url; if [[ ! "$confirm_url" =~ ^[Yy]$ ]]; then print_error "Operation cancelled."; fi; fi
fi

# 2. Get the Title
echo ""; echo "--- Step 2: Enter Link Title ---"
SUGGESTED_TITLE=$(echo "$LINK_URL" | sed -e 's|https\?://||' -e 's|www\.||' -e 's|/$||' -e 's|[/_?&=#]| |g' | sed 's/ \+/ /g' | sed -E 's/(.)([A-Z])/\1 \2/g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2);}1')
if $GUM_AVAILABLE; then LINK_TITLE=$(gum input --value "$SUGGESTED_TITLE" --placeholder "Enter a descriptive title..."); else read -p "Title (suggestion: $SUGGESTED_TITLE): " user_title; LINK_TITLE=${user_title:-$SUGGESTED_TITLE}; fi
if [[ -z "$LINK_TITLE" ]]; then print_error "Title cannot be empty."; fi

# 3. Get the Keyword/Category
echo ""; echo "--- Step 3: Select Keyword ---"
KEYWORDS_WITH_OTHER=("${CURRENT_KEYWORDS[@]}" "Other...")
if $GUM_AVAILABLE; then SELECTED_KEYWORD=$(gum choose "${KEYWORDS_WITH_OTHER[@]}" --height $((${#KEYWORDS_WITH_OTHER[@]} + 1)) --cursor="> " --header="Select category/keyword:"); else
    echo "Available keywords:"; i=1; for item in "${KEYWORDS_WITH_OTHER[@]}"; do echo "  $i) $item"; i=$((i+1)); done
    read -p "Enter number of choice: " choice_num; if [[ "$choice_num" =~ ^[0-9]+$ ]] && [ "$choice_num" -ge 1 ] && [ "$choice_num" -le ${#KEYWORDS_WITH_OTHER[@]} ]; then SELECTED_KEYWORD="${KEYWORDS_WITH_OTHER[$((choice_num-1))]}"; else print_error "Invalid choice."; fi
fi
if [[ -z "$SELECTED_KEYWORD" ]]; then print_error "No keyword selected."; fi
SAVED_NEW_KEYWORD=false
if [[ "$SELECTED_KEYWORD" == "Other..." ]]; then
    echo "- Enter custom keyword:"; if $GUM_AVAILABLE; then CUSTOM_KEYWORD=$(gum input --placeholder "New keyword (spaces '_')..."); else read -p "New keyword: " CUSTOM_KEYWORD; fi
    if [[ -z "$CUSTOM_KEYWORD" ]]; then print_error "Custom keyword cannot be empty if 'Other...' is selected."; fi
    FINAL_KEYWORD=$(echo "$CUSTOM_KEYWORD" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr ' ' '_'); if [[ -z "$FINAL_KEYWORD" ]]; then print_error "Custom keyword cannot be empty after sanitization."; fi
    save_new_keyword "$FINAL_KEYWORD"; SAVED_NEW_KEYWORD=true
else FINAL_KEYWORD=$SELECTED_KEYWORD; fi

# 4. Format the Markdown list item
MARKDOWN_LINK="*   [$LINK_TITLE]($LINK_URL) #$FINAL_KEYWORD"

# 5. Prepare target file ($TARGET_QMD_FILE defined near top)
echo ""; echo "--- Step 4: Append to File ---"
if [[ ! -f "$TARGET_QMD_FILE" ]]; then
    print_warning "Target file '$TARGET_QMD_FILE' does not exist."
    confirm_create=false; if $GUM_AVAILABLE; then if gum confirm "Create '$TARGET_QMD_FILE' now?"; then confirm_create=true; fi; else read -p "Create '$TARGET_QMD_FILE' now? [Y/n]: " confirm_create_target; if [[ ! "$confirm_create_target" =~ ^[Nn]$ ]]; then confirm_create=true; fi; fi
    if ! $confirm_create; then print_error "Target file does not exist and creation was cancelled."; fi
    mkdir -p "$(dirname "$TARGET_QMD_FILE")" || print_error "Failed to create directory for target file."
    touch "$TARGET_QMD_FILE" || print_error "Failed to create target file."
    echo "---" >> "$TARGET_QMD_FILE"; echo "title: \"Useful Links\"" >> "$TARGET_QMD_FILE"; echo "format: html" >> "$TARGET_QMD_FILE"; echo "editor: visual" >> "$TARGET_QMD_FILE"; echo "---" >> "$TARGET_QMD_FILE"; echo "" >> "$TARGET_QMD_FILE"; echo "## Links Collection" >> "$TARGET_QMD_FILE"; echo "" >> "$TARGET_QMD_FILE"
    printf -- "- Created **%s**.\n" "$TARGET_QMD_FILE"
elif [[ ! -w "$TARGET_QMD_FILE" ]]; then print_error "Target file '$TARGET_QMD_FILE' is not writable. Check permissions."; fi

# 6. Append to the file
printf -- "- Appending the following line to **%s**:\n" "$TARGET_QMD_FILE"
echo "  \`$MARKDOWN_LINK\`"
[[ $(tail -c1 "$TARGET_QMD_FILE" | wc -l) -eq 0 ]] && echo "" >> "$TARGET_QMD_FILE"
echo "$MARKDOWN_LINK" >> "$TARGET_QMD_FILE" || print_error "Failed to write to '$TARGET_QMD_FILE'."

# 7. Confirmation and Optional Render
print_success "Link added successfully to '$TARGET_QMD_FILE'."
if $SAVED_NEW_KEYWORD; then printf -- "- New keyword may have been added to '%s'.\n" "$KEYWORDS_FILE"; fi
QUARTO_MISSING=true; if command -v quarto &> /dev/null; then QUARTO_MISSING=false; fi
if ! $QUARTO_MISSING; then
     echo ""; echo "--- Step 5: Render (Optional) ---"
     do_render=false; if $GUM_AVAILABLE; then if gum confirm "Render the Quarto project ('$QUARTO_PROJECT_DIR') now?"; then do_render=true; fi; else read -p "Render the Quarto project ('$QUARTO_PROJECT_DIR') now? [y/N]: " confirm_render; if [[ "$confirm_render" =~ ^[Yy]$ ]]; then do_render=true; fi; fi
     if $do_render; then
        if [[ ! -d "$QUARTO_PROJECT_DIR" ]]; then print_error "Quarto project directory '$QUARTO_PROJECT_DIR' not found."; fi
        echo "Rendering Quarto project '$QUARTO_PROJECT_DIR'..."
        if $GUM_AVAILABLE; then gum spin --spinner="dots" --title="Rendering..." -- quarto render "$QUARTO_PROJECT_DIR" --quiet; else quarto render "$QUARTO_PROJECT_DIR" --quiet; fi
        RENDER_EXIT_CODE=$?; if [ $RENDER_EXIT_CODE -ne 0 ]; then print_warning "Quarto rendering finished with errors (Exit Code: $RENDER_EXIT_CODE)."; else printf -- "- Quarto project rendered successfully.\n"; fi
     fi
else print_warning "Skipping render option because 'quarto' command was not found."; fi

echo ""
echo "** Done. **"
exit 0
