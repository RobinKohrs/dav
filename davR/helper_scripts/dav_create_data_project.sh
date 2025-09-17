#!/usr/bin/env bash

# --- Load Shared Configuration ---
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR=$(dirname "${(%):-%x}")
else # Bash
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
fi

# Source common configuration; if it returns an error (e.g., user cancels config creation), then stop.
source "$SCRIPT_DIR/dav_common.sh"
if [ $? -ne 0 ]; then
    gum style --foreground "yellow" "Halting: Initial configuration was not completed."
    return 1
fi

# --- Script Configuration ---
SCRIPT_NAME="data-project-creator"

# --- New: Configuration for Recipes ---
DAV_RECIPES_FILE="$DAV_CONFIG_DIR/recipes.conf"

# Key specific to this script within the shared config file
THIS_SCRIPT_CONFIG_KEY_BASE_PROJECT_DIR="DATA_PROJECT_BASE_DIR"

DEFAULT_BASE_PROJECT_DIR_FALLBACK="$HOME/projects" # Fallback if nothing is configured

FZF_HEIGHT="70%"
FZF_FIND_MAX_DEPTH_CUSTOM=7
GUM_CHOOSE_HEIGHT=7
ENABLE_VERBOSE_LOGGING=false # Set to true to see detailed debug logs for this script

# --- New: Global variables for flags and recipes ---
# These will be populated by command-line arguments or a selected recipe
FLAG_PROJECT_NAME=""
FLAG_CATEGORY=""
FLAG_PARENT_DIR=""
FLAG_BASE_DIR=""
FLAG_YEAR=""
FLAG_MONTH=""
FLAG_WITH_R=""
FLAG_WITH_QGIS=""
FLAG_WITH_QUARTO=""
FLAG_QUARTO_TYPE=""
FLAG_NO_GIT_COMMIT=false
FLAG_NO_OPEN=false
FLAG_RECIPE=""

INTERACTIVE_MODE=true

# --- Helper Functions ---
check_dependency() {
  command -v "$1" >/dev/null 2>&1 || {
    gum style --foreground="red" "Error ($SCRIPT_NAME): Dependency '$1' not found." \
              "Please install it to use this script." \
              "(e.g., check $(gum style --underline "$2"))"
    return 1
  }
}

print_success_dpc() { # DPC for Data Project Creator to avoid clashes if sourced
  gum style --border="double" --border-foreground="green" --padding="1 2" \
            "Success ($SCRIPT_NAME)!" "$1" "Project root: $(gum style --bold "$2")"
}

print_error_dpc() {
  gum style --foreground="red" "Error ($SCRIPT_NAME): $1"
  return 1
}

# --- New: Help Function ---
show_help() {
  gum
  echo "Usage: $0 [options]"
  echo
  gum style --bold --foreground="blue" "Options:"
  echo "  --name <name>              Core project name (e.g., 'Tree Analysis')."
  echo "  --category <cat>           Project category: Personal, NDR, DST, or Custom."
  echo "  --parent-dir <path>        Parent directory for a 'Custom' category project."
  echo "  --base-dir <path>          Base directory for new projects (e.g., '~/projects')."
  echo "  --year <YYYY>              Set the project year."
  echo "  --month <MM>               Set the project month."
  echo "  --with-r                   Include R project components."
  echo "  --with-qgis                  Include QGIS project components."
  echo "  --with-quarto              Include Quarto project."
  echo "  --quarto-type <type>       Quarto project type: website, book, or default."
  echo "  --recipe <recipe_name>     Use a predefined recipe from '$DAV_RECIPES_FILE'."
  echo "  --no-git-commit            Skip the initial git commit."
  echo "  --no-open                  Skip opening RStudio/VSCode/QGIS at the end."
  echo "  -h, --help                 Show this help message."
  echo
  gum style --italic "Example: $0 --name \"My Report\" --category Personal --with-r --with-quarto"
  return 0
}


# Load a specific key from the shared DAV config file
load_dav_config_value() {
  local key_to_load="$1"
  local value=""
  local raw_value_from_file=""

  if [ -f "$DAV_CONFIG_FILE" ]; then
    raw_value_from_file=$(grep -E "^[[:space:]]*${key_to_load}[[:space:]]*=" "$DAV_CONFIG_FILE" | head -n 1 | cut -d'=' -f2-)
    
    local value_trimmed_whitespace
    value_trimmed_whitespace=$(echo "$raw_value_from_file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ "$value_trimmed_whitespace" == \"*\" && "$value_trimmed_whitespace" == *\" ]]; then
      value=$(echo "$value_trimmed_whitespace" | sed 's/^"//;s/"$//')
    else
      value="$value_trimmed_whitespace"
    fi
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if $ENABLE_VERBOSE_LOGGING; then
      if [ -n "$value" ] || [ -n "$raw_value_from_file" ]; then # Log if either original or cleaned has content
          gum log --level debug "Loaded '$key_to_load'. Raw: [$raw_value_from_file]. Trimmed: [$value_trimmed_whitespace]. Cleaned: [$value]"
      else
        if grep -q -E "^[[:space:]]*${key_to_load}[[:space:]]*=" "$DAV_CONFIG_FILE"; then
             gum log --level debug "$key_to_load found but empty/whitespace only. Raw: [$raw_value_from_file]. Trimmed: [$value_trimmed_whitespace]. Cleaned: [$value]"
        else
            gum log --level debug "$key_to_load not found in $DAV_CONFIG_FILE."
        fi
      fi
    fi
  else
    if $ENABLE_VERBOSE_LOGGING; then
      gum log --level debug "Shared DAV config file not found: $DAV_CONFIG_FILE"
    fi
  fi
  echo "$value"
}


# Save a specific key-value pair to the shared DAV config file
save_dav_config_value() {
  local key_to_save="$1"
  local value_to_save="$2" 
  mkdir -p "$DAV_CONFIG_DIR"

  local tmp_config_file
  tmp_config_file=$(mktemp) || { print_error_dpc "Failed to create temporary file for config."; return 1; }

  if [ ! -f "$DAV_CONFIG_FILE" ]; then
    echo "# Main DAV Configuration - $DAV_CONFIG_FILE" > "$DAV_CONFIG_FILE"
    echo "" >> "$DAV_CONFIG_FILE"
  fi

  local section_header_present=false
  if grep -q -E "^# --- For Data Project Creator.*---" "$DAV_CONFIG_FILE"; then
    section_header_present=true
  fi

  awk -v key="$key_to_save" -v val_unquoted="$value_to_save" '
    BEGIN { FS="="; OFS="="; found=0; key_regex = "^[[:space:]]*" key "[[:space:]]*$"}
    $1 ~ key_regex { 
        $2 = " \"" val_unquoted "\""
        found = 1
    }
    { print }
  ' "$DAV_CONFIG_FILE" > "$tmp_config_file"

  key_regex_for_grep="^[[:space:]]*${key_to_save}[[:space:]]*="
  if ! grep -q -E "$key_regex_for_grep" "$tmp_config_file"; then
    if ! $section_header_present && ! grep -q -E "^# --- For Data Project Creator.*---" "$tmp_config_file" ; then
        echo "" >> "$tmp_config_file" 
        echo "# --- For Data Project Creator ($SCRIPT_NAME) ---" >> "$tmp_config_file"
    elif ! $section_header_present && grep -q -E "^# --- For Data Project Creator.*---" "$DAV_CONFIG_FILE" && ! grep -q -E "^# --- For Data Project Creator.*---" "$tmp_config_file" ; then
        echo "" >> "$tmp_config_file"
        echo "# --- For Data Project Creator ($SCRIPT_NAME) ---" >> "$tmp_config_file"
    fi
    echo "${key_to_save}=\"${value_to_save}\"" >> "$tmp_config_file"
  fi

  mv "$tmp_config_file" "$DAV_CONFIG_FILE" || { rm -f "$tmp_config_file"; print_error_dpc "Failed to update config file."; return 1; }
  [ -f "$tmp_config_file" ] && rm -f "$tmp_config_file"
  gum log --level info "Saved $key_to_save=\"$value_to_save\" to shared config: $DAV_CONFIG_FILE" # This is an info log, not debug
}

# --- New: Recipe Functions ---

# Create a sample recipes file if one doesn't exist
generate_sample_recipes_file() {
  if [ ! -f "$DAV_RECIPES_FILE" ]; then
    gum format -- " - No recipe file found. Creating a sample at: **$DAV_RECIPES_FILE**"
    mkdir -p "$(dirname "$DAV_RECIPES_FILE")"
    cat << EOF_RECIPE > "$DAV_RECIPES_FILE"
# --- Data Project Creator Recipes ---
#
# This is a simple INI-style file for defining project templates.
# Each section in [brackets] is a recipe name.
#
# Supported keys:
#   description = A short description shown in the selection menu.
#   category    = Personal, NDR, DST, or Custom.
#   base_dir    = (Optional) Overrides the default base project directory.
#   parent_dir  = (Optional) Sets the parent directory if category is Custom.
#   with_r      = true / false
#   with_qgis   = true / false
#   with_quarto = true / false
#   quarto_type = website, book, default

[geospatial-report]
description = A standard project for geospatial analysis and reporting.
category = Personal
base_dir = ~/projects/geospatial # Example of overriding the base directory
with_r = true
with_qgis = true
with_quarto = true
quarto_type = website

[quick-analysis]
description = A barebones R project for a quick data check.
category = Personal
with_r = true
with_qgis = false
with_quarto = false

EOF_RECIPE
  fi
}

# List available recipes from the config file
list_recipes() {
  if [ ! -f "$DAV_RECIPES_FILE" ]; then
    return
  fi
  # Use awk to parse sections and descriptions
  awk '
    /^\[/{
      recipe=substr($0, 2, length($0)-2);
    }
    /^[[:space:]]*description[[:space:]]*=/{
      # Split at = and trim whitespace/quotes
      sub(/.*=[[:space:]]*/, "");
      sub(/^["]/, "");
      sub(/["]$/, "");
      if (recipe) {
        print recipe ": " $0;
        recipe="";
      }
    }
  ' "$DAV_RECIPES_FILE"
}

# Load settings from a chosen recipe
load_recipe() {
  local recipe_name="$1"
  if [ ! -f "$DAV_RECIPES_FILE" ]; then
    print_error_dpc "Recipe file not found: $DAV_RECIPES_FILE"
  fi

  # Use awk to read key-value pairs from the specified recipe section
  local recipe_settings
  recipe_settings=$(awk -v recipe="[$recipe_name]" '
    BEGIN{ in_section=0 }
    $0 == recipe { in_section=1; next }
    /^\[/ { in_section=0 }
    in_section && /=/ { print }
  ' "$DAV_RECIPES_FILE")

  if [ -z "$recipe_settings" ]; then
    print_error_dpc "Recipe '$recipe_name' not found or is empty in $DAV_RECIPES_FILE."
  fi

  # Read settings into our FLAG variables
  while IFS='=' read -r key value; do
    # Trim whitespace and quotes from key and value, and strip comments
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/#.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')

    case "$key" in
      category) FLAG_CATEGORY="$value" ;;
      with_r) FLAG_WITH_R="$value" ;;
      with_qgis) FLAG_WITH_QGIS="$value" ;;
      with_quarto) FLAG_WITH_QUARTO="$value" ;;
      quarto_type) FLAG_QUARTO_TYPE="$value" ;;
      base_dir) FLAG_BASE_DIR="$value" ;;
      parent_dir) FLAG_PARENT_DIR="$value" ;;
    esac
  done <<< "$recipe_settings"
  gum format -- " - Loaded recipe: **$recipe_name**"
}

# --- Dependency Checks ---
check_dependency "gum" "https://github.com/charmbracelet/gum"
check_dependency "fzf" "https://github.com/junegunn/fzf"
check_dependency "find" "Standard system utility"
check_dependency "git" "https://git-scm.com/"
check_dependency "realpath" "Standard system utility (usually coreutils)"
check_dependency "date" "Standard system utility"
check_dependency "dirname" "Standard system utility"
check_dependency "basename" "Standard system utility"
check_dependency "awk" "Standard system utility"
check_dependency "mktemp" "Standard system utility"

# --- Load Recipe if Specified ---
if [ -n "$FLAG_RECIPE" ]; then
    load_recipe "$FLAG_RECIPE"
    INTERACTIVE_MODE=false # Using a recipe implies non-interactive for subsequent steps
fi

# --- Load Configuration Specific to This Script ---
DEFAULT_BASE_PROJECT_DIR_CONFIGURED=$(load_dav_config_value "$THIS_SCRIPT_CONFIG_KEY_BASE_PROJECT_DIR")
DEFAULT_BASE_PROJECT_DIR_FOR_PROMPT="${DEFAULT_BASE_PROJECT_DIR_CONFIGURED:-$DEFAULT_BASE_PROJECT_DIR_FALLBACK}"

if $ENABLE_VERBOSE_LOGGING; then
  gum log --level debug "For prompt: DEFAULT_BASE_PROJECT_DIR_FOR_PROMPT is [$DEFAULT_BASE_PROJECT_DIR_FOR_PROMPT]"
fi

# --- Main Script ---
# Check for config file existence first
check_dav_config || return 1

CONFIG_STATUS_MSG="Shared Config: $DAV_CONFIG_FILE"
if [ ! -f "$DAV_CONFIG_FILE" ]; then
    CONFIG_STATUS_MSG="Shared Config (will be created): $DAV_CONFIG_FILE"
fi

gum style --border normal --padding "0 1" --margin "1 0" --border-foreground 212 \
          "$(gum style --bold --foreground 212 'Data Project Creator') - $(gum style --faint "$CONFIG_STATUS_MSG")"


# --- New: Recipe Selection in Interactive Mode ---
if $INTERACTIVE_MODE; then
  generate_sample_recipes_file # Create sample if it doesn't exist
  RECIPE_OPTIONS=$(list_recipes)
  if [ -n "$RECIPE_OPTIONS" ]; then
    gum format -- "Found project recipes in **$DAV_RECIPES_FILE**"
    
    # Prepend manual setup option
    CHOSEN_RECIPE_WITH_DESC=$(echo -e "Manual Setup: Create a project from scratch\n$RECIPE_OPTIONS" | gum choose --header "Select a recipe or choose manual setup:" --height 10)
    if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    
    if [ -n "$CHOSEN_RECIPE_WITH_DESC" ] && [[ "$CHOSEN_RECIPE_WITH_DESC" != "Manual Setup"* ]]; then
      # Extract just the recipe name before the colon
      CHOSEN_RECIPE=$(echo "$CHOSEN_RECIPE_WITH_DESC" | cut -d':' -f1)
      load_recipe "$CHOSEN_RECIPE"
    fi
  fi
fi


BASE_PROJECT_DIR_INPUT=""
if [ -n "$FLAG_BASE_DIR" ]; then
  BASE_PROJECT_DIR_INPUT="$FLAG_BASE_DIR"
else
  if $INTERACTIVE_MODE; then
    BASE_PROJECT_DIR_INPUT=$(gum input --header "Base directory for new projects (e.g., Personal, NDR, DST)" \
                                --placeholder "Example: ~/projects, ~/work, etc." \
                                --value "$DEFAULT_BASE_PROJECT_DIR_FOR_PROMPT" --width 70)
    if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
  else
    BASE_PROJECT_DIR_INPUT="$DEFAULT_BASE_PROJECT_DIR_FOR_PROMPT" # Use default in non-interactive mode
  fi
fi
if [ -z "$BASE_PROJECT_DIR_INPUT" ]; then print_error_dpc "Base project directory cannot be empty."; fi

CLEANED_BASE_PROJECT_DIR_INPUT=$(echo "$BASE_PROJECT_DIR_INPUT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ "$CLEANED_BASE_PROJECT_DIR_INPUT" != "$DEFAULT_BASE_PROJECT_DIR_CONFIGURED" ] || [ -z "$DEFAULT_BASE_PROJECT_DIR_CONFIGURED" ]; then
    save_dav_config_value "$THIS_SCRIPT_CONFIG_KEY_BASE_PROJECT_DIR" "$CLEANED_BASE_PROJECT_DIR_INPUT"
    DEFAULT_BASE_PROJECT_DIR_CONFIGURED="$CLEANED_BASE_PROJECT_DIR_INPUT"
fi
BASE_PROJECT_DIR_TO_USE="$CLEANED_BASE_PROJECT_DIR_INPUT"


TEMP_BASE_PATH="${BASE_PROJECT_DIR_TO_USE/#\~/$HOME}"
if [[ "$TEMP_BASE_PATH" != /* ]]; then TEMP_BASE_PATH="$(pwd)/$TEMP_BASE_PATH"; fi

BASE_PROJECT_DIR_RESOLVED=""
if [ ! -d "$TEMP_BASE_PATH" ]; then
    if gum confirm "Base project directory '$TEMP_BASE_PATH' does not exist. Create it?" --default=true; then
      mkdir -p "$TEMP_BASE_PATH" || print_error_dpc "Failed to create base directory '$TEMP_BASE_PATH'."
      BASE_PROJECT_DIR_RESOLVED=$(realpath "$TEMP_BASE_PATH")
      gum format -- "- Created base project directory: **$BASE_PROJECT_DIR_RESOLVED**"
    else
      print_error_dpc "Base project directory '$TEMP_BASE_PATH' not found and not created."
    fi
else
    if [ ! -d "$TEMP_BASE_PATH" ]; then print_error_dpc "Path '$TEMP_BASE_PATH' exists but is not a directory."; fi
    BASE_PROJECT_DIR_RESOLVED=$(realpath "$TEMP_BASE_PATH")
    gum format -- "- Using base project directory: **$BASE_PROJECT_DIR_RESOLVED**"
fi

PROJECT_CATEGORY=""
if [ -n "$FLAG_CATEGORY" ]; then
  # Validate the category from the flag
  case "$FLAG_CATEGORY" in
    Personal|NDR|DST|"Custom (select parent directory anywhere)")
      PROJECT_CATEGORY="$FLAG_CATEGORY"
      ;;
    Custom) # Allow shorthand "Custom"
      PROJECT_CATEGORY="Custom (select parent directory anywhere)"
      ;;
    *)
      print_error_dpc "Invalid category '$FLAG_CATEGORY' from flag. Use Personal, NDR, DST, or Custom."
      ;;
  esac
else
  if $INTERACTIVE_MODE; then
    PROJECT_CATEGORY=$(gum choose "Personal" "NDR" "DST" "Custom (select parent directory anywhere)" --header "Select project category:" --height "$GUM_CHOOSE_HEIGHT")
    if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
  else
    print_error_dpc "Project category must be specified in non-interactive mode (e.g., --category Personal)."
  fi
fi
if [ -z "$PROJECT_CATEGORY" ]; then print_error_dpc "No project category selected."; fi

TARGET_PROJECT_ROOT_DIR=""
PROJECT_NAME_FOR_FILES=""
CORE_PROJECT_NAME_DISPLAY=""

if [[ "$PROJECT_CATEGORY" == "Personal" || "$PROJECT_CATEGORY" == "NDR" || "$PROJECT_CATEGORY" == "DST" ]]; then
  gum format -- "- Selected category: **$PROJECT_CATEGORY** (will be under '$BASE_PROJECT_DIR_RESOLVED')"
  CURRENT_YEAR=$(date +%Y)
  PROJECT_YEAR=""
  if [ -n "$FLAG_YEAR" ]; then
    PROJECT_YEAR="$FLAG_YEAR"
  else
    if $INTERACTIVE_MODE; then
      PROJECT_YEAR=$(gum input --placeholder "Enter year (YYYY)" --value "$CURRENT_YEAR" --header "Project Year:")
      if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    else
      PROJECT_YEAR="$CURRENT_YEAR"
    fi
  fi
  if ! [[ "$PROJECT_YEAR" =~ ^[0-9]{4}$ ]]; then print_error_dpc "Invalid year format. Please use YYYY."; fi
  CURRENT_MONTH=$(date +%m)
  PROJECT_MONTH_INPUT=""
  if [ -n "$FLAG_MONTH" ]; then
    PROJECT_MONTH_INPUT="$FLAG_MONTH"
  else
    if $INTERACTIVE_MODE; then
      PROJECT_MONTH_INPUT=$(gum input --placeholder "Enter month (MM, e.g., 07)" --value "$CURRENT_MONTH" --header "Project Month:")
      if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    else
      PROJECT_MONTH_INPUT="$CURRENT_MONTH"
    fi
  fi
  if ! [[ "$PROJECT_MONTH_INPUT" =~ ^(0?[1-9]|1[0-2])$ ]]; then print_error_dpc "Invalid month format. MM (01-12)."; fi
  PROJECT_MONTH=$(printf "%02d" "${PROJECT_MONTH_INPUT#0}")
  CORE_PROJECT_NAME_DISPLAY=""
  if [ -n "$FLAG_PROJECT_NAME" ]; then
    CORE_PROJECT_NAME_DISPLAY="$FLAG_PROJECT_NAME"
  else
    if $INTERACTIVE_MODE; then
      CORE_PROJECT_NAME_DISPLAY=$(gum input --placeholder "Enter a short name for your project (e.g., 'Tree Analysis')" --header "Core Project Name:")
      if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    else
      print_error_dpc "Project name must be specified in non-interactive mode (e.g., --name 'My Project')."
    fi
  fi
  if [ -z "$CORE_PROJECT_NAME_DISPLAY" ]; then print_error_dpc "Core project name cannot be empty."; fi
  PROJECT_NAME_FOR_FILES=$(echo "$CORE_PROJECT_NAME_DISPLAY" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g' | sed 's:/*$::')
  if [ -z "$PROJECT_NAME_FOR_FILES" ]; then print_error_dpc "Sanitized project name is empty. Use alphanumeric characters."; fi
  gum format -- "- Core project name (for files & dir part) set to: **$PROJECT_NAME_FOR_FILES**"
  PROJECT_CATEGORY_LOWER=$(echo "$PROJECT_CATEGORY" | tr '[:upper:]' '[:lower:]')
  
  # Unified directory structure for all categories
  PROJECT_DIR_LEAF_NAME="$PROJECT_YEAR-$PROJECT_MONTH-$PROJECT_NAME_FOR_FILES"
  TARGET_PROJECT_ROOT_DIR="$BASE_PROJECT_DIR_RESOLVED/$PROJECT_CATEGORY_LOWER/$PROJECT_YEAR/$PROJECT_DIR_LEAF_NAME"
elif [[ "$PROJECT_CATEGORY" == "Custom (select parent directory anywhere)" ]]; then
  gum format -- "- Selected category: **Custom**"
  CORE_PROJECT_NAME_DISPLAY=""
  if [ -n "$FLAG_PROJECT_NAME" ]; then
      CORE_PROJECT_NAME_DISPLAY="$FLAG_PROJECT_NAME"
  else
    if $INTERACTIVE_MODE; then
      CORE_PROJECT_NAME_DISPLAY=$(gum input --placeholder "Enter a name for your new project folder (e.g., 'Ad Hoc Report')" --header "Project Folder Name:")
      if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    else
      print_error_dpc "Project name must be specified for custom projects in non-interactive mode (e.g., --name 'My Project')."
    fi
  fi
  if [ -z "$CORE_PROJECT_NAME_DISPLAY" ]; then print_error_dpc "Project folder name cannot be empty for custom project."; fi
  PROJECT_NAME_FOR_FILES=$(echo "$CORE_PROJECT_NAME_DISPLAY" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g' | sed 's:/*$::')
  if [ -z "$PROJECT_NAME_FOR_FILES" ]; then print_error_dpc "Sanitized project name is empty. Use alphanumeric characters."; fi
  gum format -- "- Project name (for files and folder) set to: **$PROJECT_NAME_FOR_FILES**"
  
  PARENT_DIR_FOR_CUSTOM_SELECTED=""
  if [ -n "$FLAG_PARENT_DIR" ]; then
    PARENT_DIR_FOR_CUSTOM_SELECTED="$FLAG_PARENT_DIR"
    if [[ ! -d "$PARENT_DIR_FOR_CUSTOM_SELECTED" ]]; then
        # In non-interactive mode, we can create it.
        mkdir -p "$PARENT_DIR_FOR_CUSTOM_SELECTED" || print_error_dpc "Failed to create parent directory '$PARENT_DIR_FOR_CUSTOM_SELECTED'."
        gum log --level info "Created parent directory for custom project: $PARENT_DIR_FOR_CUSTOM_SELECTED"
    fi
  else
    if ! $INTERACTIVE_MODE; then
      print_error_dpc "Parent directory must be specified for custom projects in non-interactive mode (e.g., --parent-dir /path/to/parent)."
    fi

    gum format -- "- $(gum style --bold 'Select PARENT directory for the new project folder using fzf.')"
    gum format -- "  - Searching from $(gum style --bold \$HOME) up to depth $FZF_FIND_MAX_DEPTH_CUSTOM. You can type to filter."
    gum format -- "  - $(gum style --italic 'Tip: Type part of the path, e.g., \"work/clients\" or \"/var/www\"')"
    PARENT_DIR_FOR_CUSTOM_SELECTED=$( \
      ( \
        gum spin --show-output --spinner="line" --title="Searching for directories (max depth $FZF_FIND_MAX_DEPTH_CUSTOM from $HOME)..." -- \
        find "$HOME" -maxdepth "$FZF_FIND_MAX_DEPTH_CUSTOM" -path "$HOME/Library" -prune -o -path "$HOME/Applications" -prune -o -path "$HOME/.Trash" -prune -o -type d \
        \( -name ".git" -o -name "node_modules" -o -name ".cache" -o -name "venv" -o -name ".venv" -o -path "*/.*/*" \) -prune \
        -o -print 2>/dev/null \
      ) | fzf --header="Select PARENT directory for '$PROJECT_NAME_FOR_FILES' (searching from $HOME, max depth $FZF_FIND_MAX_DEPTH_CUSTOM)" \
               --height="$FZF_HEIGHT" --border --exit-0 --select-1 --no-multi \
               --preview='ls -lah --color=always {} | head -n 20' \
    )
    FZF_EXIT_CODE=$?
    if [ $FZF_EXIT_CODE -ne 0 ] || [ -z "$PARENT_DIR_FOR_CUSTOM_SELECTED" ]; then
        if [ $FZF_EXIT_CODE -eq 130 ]; then print_error_dpc "Parent directory selection cancelled via fzf. Aborting."; fi
        gum style --foreground="yellow" --margin="1 0" "Fzf selection failed or was empty."
        if gum confirm "Try manual path input with Tab completion instead?" --default=true; then
            echo ""
            gum style --bold --padding "0 0 1 0" "Enter the PARENT directory for the new '$PROJECT_NAME_FOR_FILES' folder."
            gum style --italic "  You can use $(gum style --bold Tab) for path completion. Start with $(gum style --bold ~/ ) or $(gum style --bold / )"
            read -e -p "  Parent Directory: " -i "$HOME/" PARENT_DIR_FOR_CUSTOM_INPUTTED
            echo ""
            if [ -z "$PARENT_DIR_FOR_CUSTOM_INPUTTED" ]; then print_error_dpc "No parent directory entered manually. Aborting."; fi
            PARENT_DIR_FOR_CUSTOM_EXPANDED="${PARENT_DIR_FOR_CUSTOM_INPUTTED/#\~/$HOME}"
            PARENT_DIR_FOR_CUSTOM_EXPANDED="${PARENT_DIR_FOR_CUSTOM_EXPANDED%/}"
            if [ ! -d "$PARENT_DIR_FOR_CUSTOM_EXPANDED" ]; then
                if gum confirm "Parent directory '$PARENT_DIR_FOR_CUSTOM_EXPANDED' does not exist. Create it?" --default=true; then
                     mkdir -p "$PARENT_DIR_FOR_CUSTOM_EXPANDED" || print_error_dpc "Failed to create parent directory '$PARENT_DIR_FOR_CUSTOM_EXPANDED'."
                else
                    print_error_dpc "Parent directory '$PARENT_DIR_FOR_CUSTOM_EXPANDED' not found and not created. Aborting."
                fi
            fi
            if [ ! -d "$PARENT_DIR_FOR_CUSTOM_EXPANDED" ]; then print_error_dpc "Path '$PARENT_DIR_FOR_CUSTOM_EXPANDED' is not a valid directory. Aborting."; fi
            PARENT_DIR_FOR_CUSTOM_SELECTED="$PARENT_DIR_FOR_CUSTOM_EXPANDED"
        else
            print_error_dpc "No parent directory selected. Aborting."
        fi
    fi
  fi
  PARENT_DIR_FOR_CUSTOM=$(realpath "$PARENT_DIR_FOR_CUSTOM_SELECTED")
  gum format -- "- Selected parent directory for custom project: **$PARENT_DIR_FOR_CUSTOM**"
  TARGET_PROJECT_ROOT_DIR="$PARENT_DIR_FOR_CUSTOM/$PROJECT_NAME_FOR_FILES"
else
    print_error_dpc "Invalid project category selected. This should not happen."
fi

gum format -- "- Target project root will be: **$TARGET_PROJECT_ROOT_DIR**"
PROJECT_ROOT_DIR=""
if [ -e "$TARGET_PROJECT_ROOT_DIR" ]; then
  if ! gum confirm "Path '$TARGET_PROJECT_ROOT_DIR' already exists. Continue and potentially add/overwrite files?" --default=false; then
    echo "Operation cancelled by user."; return 0;
  fi
  gum format -- "- Proceeding with existing path..."
  if [ ! -d "$TARGET_PROJECT_ROOT_DIR" ]; then print_error_dpc "Path '$TARGET_PROJECT_ROOT_DIR' exists but is not a directory."; fi
  PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR")
else
  mkdir -p "$TARGET_PROJECT_ROOT_DIR" || print_error_dpc "Failed to create directory '$TARGET_PROJECT_ROOT_DIR'."
  PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR")
fi

cd "$PROJECT_ROOT_DIR" || print_error_dpc "Failed to change directory to $PROJECT_ROOT_DIR"
gum format -- "- Changed directory to: **$(pwd)**"

GIT_INITIALIZED_NOW=false
if [ ! -d ".git" ]; then
    gum spin --show-output --spinner="dot" --title="Initializing Git repository..." -- git init -q || print_error_dpc "Failed to initialize Git repository."
    GIT_INITIALIZED_NOW=true; gum format -- "- Initialized Git repository."
else
    gum format -- "- Git repository already exists."
fi

gum format -- "- Creating minimal .gitignore (relying on smart git add for intelligent file handling)..."
cat << EOF_GITIGNORE > ".gitignore"
# R history files
.Rhistory

# Backup files
*~
EOF_GITIGNORE


gum format -- "- Creating common project subdirectories..."
mkdir -p "data_raw/geodata" "data_raw/tabular" \
           "data_output" "graphic_output" "docs" "scripts"
gum format -- "- Created: data_raw/geodata/, data_raw/tabular/, data_output/, graphic_output/, docs/, scripts/"

ADD_R=false; ADD_QGIS=false; ADD_QUARTO=false
RPROJ_FILE_ABS="$PROJECT_ROOT_DIR/$PROJECT_NAME_FOR_FILES.Rproj"
R_SPECIFIC_SUBDIRS_PATH="$PROJECT_ROOT_DIR/R"

if [ -z "$FLAG_WITH_R" ]; then
  if $INTERACTIVE_MODE; then
    if gum confirm "Add R project components? ($PROJECT_NAME_FOR_FILES.Rproj in root, specific subdirs in R/)?"; then
      FLAG_WITH_R=true
    else
      FLAG_WITH_R=false
    fi
  else
    FLAG_WITH_R=false # Default to false in non-interactive
  fi
fi

if [ "$FLAG_WITH_R" = true ]; then
  ADD_R=true; gum spin --show-output --spinner="dot" --title="Setting up R components..." -- sleep 0.5
  mkdir -p "$R_SPECIFIC_SUBDIRS_PATH/analysis" "$R_SPECIFIC_SUBDIRS_PATH/functions"
  cat << EOF_RPROJ > "$RPROJ_FILE_ABS"
Version: 1.0
ProjectName: $PROJECT_NAME_FOR_FILES

RestoreWorkspace: Default
SaveWorkspace: Default
AlwaysSaveHistory: Default

EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8

RnwWeave: Sweave
LaTeX: pdfLaTeX

# --------------------------------------------------------------------------
# Project Information (generated by $SCRIPT_NAME)
#
# Project Display Name: $CORE_PROJECT_NAME_DISPLAY
# Project Identifier (for files/dirs): $PROJECT_NAME_FOR_FILES
# Project Root Directory: $PROJECT_ROOT_DIR
#
# Recommended R project structure:
# - R scripts/functions should ideally go into: ./R/
# - Raw data is typically stored in: ./data_raw/
# - Processed data or outputs can be saved to: ./data_output/
#
# For robust file paths within R scripts, consider using the 'here' package:
# e.g., data_path <- here::here("data_raw", "my_input_file.csv")
#
# This project file was created on: $(date +"%Y-%m-%d %H:%M:%S")
# Script responsible for creation: $SCRIPT_NAME
# --------------------------------------------------------------------------
EOF_RPROJ
  gum format -- "- Added R project file: **$RPROJ_FILE_ABS**"
  gum format -- "- Added R specific subdirectories in: **$R_SPECIFIC_SUBDIRS_PATH/**"
fi

QGIS_PROJ_FILE_ABS="$PROJECT_ROOT_DIR/$PROJECT_NAME_FOR_FILES.qgs"
QGIS_SPECIFIC_SUBDIRS_PATH="$PROJECT_ROOT_DIR/qgis"
QGIS_SAVE_USER="${USER:-unknown_user}"
QGIS_SAVE_DATETIME=$(date +"%Y-%m-%dT%H:%M:%S")
QGIS_CREATION_DATE=$(date +"%Y-%m-%d")

if [ -z "$FLAG_WITH_QGIS" ]; then
  if $INTERACTIVE_MODE; then
    if gum confirm "Add QGIS project components? ($PROJECT_NAME_FOR_FILES.qgs in root, specific subdirs in qgis/)?"; then
      FLAG_WITH_QGIS=true
    else
      FLAG_WITH_QGIS=false
    fi
  else
    FLAG_WITH_QGIS=false # Default to false
  fi
fi

if [ "$FLAG_WITH_QGIS" = true ]; then
  ADD_QGIS=true; gum spin --show-output --spinner="line" --title="Setting up QGIS components..." -- sleep 0.5
  mkdir -p "$QGIS_SPECIFIC_SUBDIRS_PATH/scripts" "$QGIS_SPECIFIC_SUBDIRS_PATH/models" "$QGIS_SPECIFIC_SUBDIRS_PATH/styles"
  gum format -- "- Added QGIS specific subdirectories in **$QGIS_SPECIFIC_SUBDIRS_PATH/**"
  gum format -- "- Note: Common geodata is expected in **$PROJECT_ROOT_DIR/data_raw/geodata/**"
  cat << EOF_QGIS > "$QGIS_PROJ_FILE_ABS"
<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis saveUser="$QGIS_SAVE_USER" saveDateTime="$QGIS_SAVE_DATETIME" version="3.34.0-Prizzi" projectname="$PROJECT_NAME_FOR_FILES" saveUserFull="$QGIS_SAVE_USER">
  <homePath path="."/>
  <title>$CORE_PROJECT_NAME_DISPLAY</title>
  <projectproperties>
    <paths relativePaths="1"/>
    <measurements ellipsoid="EPSG:7030"/>
    <PAL labellingEngine=" migliorare"/>
  </projectproperties>
  <mapcanvas annotationsVisible="1" name="theMapCanvas">
    <units>degrees</units>
    <extent><xmin>-1</xmin><ymin>-1</ymin><xmax>1</xmax><ymax>1</ymax></extent>
    <projectionacronym>longlat</projectionacronym>
    <destinationsrs><spatialrefsys nativeFormat="Wkt"><wkt>GEOGCRS["WGS 84",ENSEMBLE["World Geodetic System 1984 ensemble",MEMBER["World Geodetic System 1984 (Transit)"],MEMBER["World Geodetic System 1984 (G730)"],MEMBER["World Geodetic System 1984 (G873)"],MEMBER["World Geodetic System 1984 (G1150)"],MEMBER["World Geodetic System 1984 (G1674)"],MEMBER["World Geodetic System 1984 (G1762)"],ELLIPSOID["WGS 84",6378137,298.257223563,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[2.0]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["geodetic latitude (Lat)",north,ORDER[1],ANGLEUNIT["degree",0.0174532925199433]],AXIS["geodetic longitude (Lon)",east,ORDER[2],ANGLEUNIT["degree",0.0174532925199433]],USAGE[SCOPE["Horizontal component of 3D system."],AREA["World."],BBOX[-90,-180,90,180]],ID["EPSG",4326]]</wkt><proj4>+proj=longlat +datum=WGS84 +no_defs</proj4><srsid>3452</srsid><srid>4326</srid><authid>EPSG:4326</authid><description>WGS 84</description><projectionacronym>longlat</projectionacronym><ellipsoidacronym>EPSG:7030</ellipsoidacronym><geographicflag>true</geographicflag></spatialrefsys></destinationsrs>
  </mapcanvas>
  <projectMetadata><title>$CORE_PROJECT_NAME_DISPLAY</title><abstract>GIS project for $CORE_PROJECT_NAME_DISPLAY.
Raw geodata stored in: ./data_raw/geodata/
Output data in: ./data_output/
Graphic outputs in: ./graphic_output/
QGIS specific files (models, styles) in: ./qgis/</abstract><author>$QGIS_SAVE_USER</author><creation>$QGIS_SAVE_DATETIME</creation></projectMetadata>
  <!-- Add other QGIS project content as needed -->
</qgis>
EOF_QGIS
  gum format -- "- Created QGIS project file: **$QGIS_PROJ_FILE_ABS**"
fi

if [ -z "$FLAG_WITH_QUARTO" ]; then
  if $INTERACTIVE_MODE; then
    if gum confirm "Initialize a Quarto project in the root directory?"; then
      FLAG_WITH_QUARTO=true
    else
      FLAG_WITH_QUARTO=false
    fi
  else
    FLAG_WITH_QUARTO=false # Default to false
  fi
fi

if [ "$FLAG_WITH_QUARTO" = true ]; then
  ADD_QUARTO=true
  check_dependency "quarto" "https://quarto.org/docs/get-started/"
  QUARTO_PROJECT_TYPE_INPUT=""
  if [ -n "$FLAG_QUARTO_TYPE" ]; then
    QUARTO_PROJECT_TYPE_INPUT="$FLAG_QUARTO_TYPE"
  else
    if $INTERACTIVE_MODE; then
      QUARTO_PROJECT_TYPE_INPUT=$(gum choose "website" "book" "default (simple project)" --header "Select Quarto project type:" --height "$GUM_CHOOSE_HEIGHT")
      if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
    else
      QUARTO_PROJECT_TYPE_INPUT="default" # Default in non-interactive mode
    fi
  fi

  if [ -z "$QUARTO_PROJECT_TYPE_INPUT" ]; then
      gum style --foreground="yellow" "No Quarto project type selected. Skipping Quarto setup."
      ADD_QUARTO=false
  else
      QUARTO_PROJECT_TYPE_CMD=$(echo "$QUARTO_PROJECT_TYPE_INPUT" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
      QUARTO_OUTPUT="" QUARTO_ERROR="" stderr_file_quarto=$(mktemp)
      if [ -z "$stderr_file_quarto" ] || [ ! -f "$stderr_file_quarto" ]; then print_error_dpc "Failed to create temporary file for Quarto error log."; fi
      
      if $ENABLE_VERBOSE_LOGGING; then
        gum log --level debug "Attempting to initialize Quarto project: quarto create-project . --type \"$QUARTO_PROJECT_TYPE_CMD\""
      fi
      
      if ! QUARTO_OUTPUT=$(quarto create-project . --type "$QUARTO_PROJECT_TYPE_CMD" 2> "$stderr_file_quarto"); then
          QUARTO_ERROR=$(<"$stderr_file_quarto"); rm -f "$stderr_file_quarto"
          gum style --foreground="red" --border="heavy" --padding="1" "Quarto Initialization Failed!" "Type: $QUARTO_PROJECT_TYPE_CMD" "Project Root: $(pwd)"
          echo "$QUARTO_ERROR" | gum style --foreground="red" --stdin --padding="0 1" --border="normal" --border-foreground="red" --title="Quarto's Error Message"
          if [ -n "$QUARTO_OUTPUT" ]; then echo "$QUARTO_OUTPUT" | gum style --foreground="yellow" --stdin --padding="0 1" --border="normal" --border-foreground="yellow" --title="Quarto's Standard Output (if any)"; fi
          if gum confirm "Quarto project initialization failed. Continue without Quarto components?" --default=false --affirmative="Continue without Quarto" --negative="Abort Script"; then
            ADD_QUARTO=false; gum style --foreground="yellow" "Proceeding without Quarto components."
          else return 1; fi
      else
          rm -f "$stderr_file_quarto"
          gum format -- "- Initialized Quarto $QUARTO_PROJECT_TYPE_CMD project at **$PROJECT_ROOT_DIR**"
          gum format -- "  - Primary configuration: **_quarto.yml**"
          if [ -f "index.qmd" ]; then gum format -- "  - Main document: **index.qmd**"; fi
          if [ -f "${PROJECT_NAME_FOR_FILES}.qmd" ]; then gum format -- "  - Main document: **${PROJECT_NAME_FOR_FILES}.qmd**"; fi
      fi
  fi
fi

gum format -- "- Creating README.md..."
GIT_USER_NAME=$(git config user.name); GIT_USER_EMAIL=$(git config user.email); CONTACT_INFO=""
if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then CONTACT_INFO="- $GIT_USER_NAME <$GIT_USER_EMAIL>";
elif [ -n "$GIT_USER_NAME" ]; then CONTACT_INFO="- $GIT_USER_NAME (email not configured in git)";
else CONTACT_INFO="- (Configure your git user.name and user.email for contact info)"; fi

cat << EOF_README > "README.md"
# $CORE_PROJECT_NAME_DISPLAY

## Project Overview
(A brief description of the project goals, methods, and expected outcomes.)

## Created On
$(date +"%Y-%m-%d %H:%M:%S") by $SCRIPT_NAME

## Directory Structure
- \`PROJECT_ROOT/\` ($(realpath .))
  - \`data_raw/\`: Raw, immutable input data.
    - \`geodata/\`: Raw geospatial data.
    - \`tabular/\`: Raw tabular data.
  - \`data_output/\`: Processed data, intermediate files, and final outputs derived from \`data_raw/\`.
  - \`graphic_output/\`: Charts, maps, and other visual outputs.
  - \`scripts/\`: General purpose scripts (e.g., Python, shell) not specific to R or QGIS workflows.
  - \`docs/\`: Project documentation, reports, notes, literature.
$(if $ADD_R; then echo "  - \`R/\`: R specific files."; echo "    - \`analysis/\`: R Markdown/Quarto scripts for analysis, main R scripts."; echo "    - \`functions/\`: Custom R functions."; fi)
$(if $ADD_QGIS; then echo "  - \`qgis/\`: QGIS specific files."; echo "    - \`models/\`: QGIS processing models."; echo "    - \`scripts/\`: QGIS processing Python scripts."; echo "    - \`styles/\`: QGIS layer styles (.qml)."; fi)
  - \`.gitignore\`: Specifies intentionally untracked files that Git should ignore.
$(if $ADD_R; then echo "  - \`$PROJECT_NAME_FOR_FILES.Rproj\`: RStudio Project file. Open this to work with R in this project."; fi)
$(if $ADD_QGIS; then echo "  - \`$PROJECT_NAME_FOR_FILES.qgs\`: QGIS Project file. Open this to work with QGIS in this project."; fi)
$(if $ADD_QUARTO; then echo "  - \`_quarto.yml\`: Quarto project configuration file."; \
                     if [ -f "index.qmd" ]; then echo "  - \`index.qmd\`: Main Quarto document (e.g., website homepage or book preface)."; \
                     elif [ -f "${PROJECT_NAME_FOR_FILES}.qmd" ]; then echo "  - \`${PROJECT_NAME_FOR_FILES}.qmd\`: Main Quarto document."; fi; \
                     if [ -f "about.qmd" ]; then echo "  - \`about.qmd\`: Example Quarto page (if 'website' or 'book' type chosen)."; fi; fi)

## Getting Started
1.  **Clone the repository (if applicable).**
2.  **Install dependencies:**
    - (Specify R packages, Python packages, system libraries, etc.)
    - (If using Python, consider a virtual environment: \`python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt\`)
3.  **Data:**
    - Place raw data in \`data_raw/\`.
    - Scripts should read from \`data_raw/\` and write to \`data_output/\`.
$(if $ADD_R; then echo "4.  **R:** Open \`$PROJECT_NAME_FOR_FILES.Rproj\` in RStudio. Use the \`here\` package for path management (e.g., \`here::here(\"data_raw\", \"my_file.csv\")\`)."; fi)
$(if $ADD_QGIS; then echo "5.  **QGIS:** Open \`$PROJECT_NAME_FOR_FILES.qgs\` in QGIS. Ensure paths to data layers are relative or correctly set."; fi)
$(if $ADD_QUARTO; then echo "6.  **Quarto:** To render the project, navigate to the project root in your terminal and run \`quarto render\`. For a preview during development, run \`quarto preview\`."; fi)
## Key Contacts
$CONTACT_INFO
## Notes
(Any other important information or conventions for this project.)
EOF_README
gum format -- "- Created README.md"

if $GIT_INITIALIZED_NOW ; then
    DO_COMMIT=false
    if $FLAG_NO_GIT_COMMIT; then
      DO_COMMIT=false
    elif $INTERACTIVE_MODE; then
      if gum confirm "Make an initial Git commit with the generated structure?" --default=true; then
        DO_COMMIT=true
      fi
    else
      DO_COMMIT=true # Default to commit in non-interactive mode unless --no-git-commit
    fi

    if $DO_COMMIT; then
        git add .gitignore README.md
        git add data_raw/ data_output/ graphic_output/ docs/ scripts/
        if $ADD_R; then git add "$PROJECT_NAME_FOR_FILES.Rproj" R/; fi
        if $ADD_QGIS; then git add "$PROJECT_NAME_FOR_FILES.qgs" qgis/; fi
        if $ADD_QUARTO; then
            git add _quarto.yml
            if [ -f "index.qmd" ]; then git add index.qmd; fi
            if [ -f "${PROJECT_NAME_FOR_FILES}.qmd" ]; then git add "${PROJECT_NAME_FOR_FILES}.qmd"; fi
            if [ -f "about.qmd" ]; then git add "about.qmd"; fi
        fi
        if ! git diff --cached --quiet; then
            COMMIT_MSG="Initial project structure for '$CORE_PROJECT_NAME_DISPLAY' created by $SCRIPT_NAME"
            gum spin --show-output --spinner="dot" --title="Making initial Git commit..." -- \
            git commit -m "$COMMIT_MSG" -q || gum style --foreground="yellow" "Warning: Initial commit failed."
            gum format -- "- Made initial Git commit."
        else gum format -- "- No changes to commit for initial setup (or files already tracked)."; fi
    fi
fi

if [ "$FLAG_NO_OPEN" = true ]; then
  gum format -- "- Skipping final step to open project in editors/IDEs."
  print_success_dpc "$SUMMARY_MSG" "$PROJECT_ROOT_DIR"
  return 0
fi

# --- New: Add Alias Section ---
add_cd_alias() {
    local alias_file="$HOME/.zshrc" # Assuming zsh, common for modern macOS/Linux
    if [ ! -f "$alias_file" ]; then
        # Fallback for bash if .zshrc doesn't exist
        if [ -f "$HOME/.bashrc" ]; then
            alias_file="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            alias_file="$HOME/.bash_profile"
        else
            gum style --foreground="yellow" "Warning: Could not find .zshrc, .bashrc, or .bash_profile to add project function."
            return
        fi
    fi

    if gum confirm "Add a shell function to open this project to '$alias_file'?" --default=true; then
        local suggested_alias
        suggested_alias=$(basename "$PROJECT_ROOT_DIR" | sed 's/^[0-9]\{4\}_[0-9]\{2\}_//' | sed 's/^[0-9]\{4\}-[0-9]\{2\}-//')
        
        local func_name
        func_name=$(gum input --header "Enter function name (will act like an alias)" --value "p_$suggested_alias" --placeholder "e.g., p_my_analysis")
        if [ $? -ne 0 ]; then print_error_dpc "Operation cancelled by user."; return 1; fi
        if [ -z "$func_name" ]; then
            gum style --foreground="yellow" "No function name entered. Skipping."
            return
        fi

        # Check if function already exists. This is a simple check for the function definition.
        if grep -q -E "^(function[[:space:]]+)?${func_name}[[:space:]]*\(\)" "$alias_file"; then
            if gum confirm "Function '$func_name' seems to already exist in '$alias_file'. Overwrite it?" --default=false; then
                # A simple strategy for "overwrite" is to comment out the old block if we can find it.
                # A truly robust solution is complex, so for now we'll just append and let the user manage conflicts.
                 gum format -- " - Proceeding to add new function. Please manually resolve any conflicts in **$alias_file**."
            else
                gum style --foreground="yellow" "Skipping function creation."
                return
            fi
        fi

        gum format -- " - Adding function to **$alias_file**..."
        
        # Using a heredoc to write the multi-line function
        # Note: We escape `$` for variables that should be evaluated when the function is RUN, not when it's written.
        cat << EOF_FUNC >> "$alias_file"

# Function to open project '$CORE_PROJECT_NAME_DISPLAY', created by $SCRIPT_NAME on $(date)
function ${func_name}() {
    echo "Opening project: $(gum style --bold '$CORE_PROJECT_NAME_DISPLAY')"
    cd "$PROJECT_ROOT_DIR" || { echo "Error: Could not cd to '$PROJECT_ROOT_DIR'"; return 1; }

    local os_type
    os_type=\$(uname -s)
    local launch_cmd=""

    if [[ "\$os_type" == "Darwin" ]]; then
        launch_cmd="open"
    elif [[ "\$os_type" == "Linux" ]]; then
        launch_cmd="xdg-open"
    fi

    # Open RStudio Project if it was created
    if [ "$ADD_R" = true ] && [ -f "$RPROJ_FILE_ABS" ]; then
        if [[ -n "\$launch_cmd" ]] && command -v "\$launch_cmd" >/dev/null 2>&1; then
            echo " -> Launching RStudio Project..."
            ( "\$launch_cmd" "$RPROJ_FILE_ABS" &>/dev/null & )
        elif command -v rstudio >/dev/null 2>&1; then
            echo " -> Launching RStudio Project..."
            ( rstudio "$RPROJ_FILE_ABS" &>/dev/null & )
        fi
    fi

    # Open QGIS Project if it was created
    if [ "$ADD_QGIS" = true ] && [ -f "$QGIS_PROJ_FILE_ABS" ]; then
        if [[ -n "\$launch_cmd" ]] && command -v "\$launch_cmd" >/dev/null 2>&1; then
            echo " -> Launching QGIS Project..."
            ( "\$launch_cmd" "$QGIS_PROJ_FILE_ABS" &>/dev/null & )
        elif command -v qgis >/dev/null 2>&1; then
            echo " -> Launching QGIS Project..."
            ( qgis "$QGIS_PROJ_FILE_ABS" &>/dev/null & )
        fi
    fi

    # Open project in Cursor or VS Code
    if command -v cursor >/dev/null 2>&1; then
        echo " -> Opening directory in Cursor..."
        cursor .
    elif command -v code >/dev/null 2>&1; then
        echo " -> Opening directory in VS Code..."
        code .
    else
        echo " -> Neither 'cursor' nor 'code' found. Staying in the terminal."
    fi
}
EOF_FUNC

        gum style --border double --padding "1" --border-foreground "cyan" \
            "Function '$func_name' added successfully!" \
            "To use it, run: $(gum style --bold 'source '$alias_file') or open a new terminal, then type: $(gum style --bold '$func_name')"
    fi
}

# --- New: Function to offer adding an alias for this script ---
offer_to_add_script_alias() {
    local alias_file="$HOME/.zshrc"
    if [ ! -f "$alias_file" ]; then
        if [ -f "$HOME/.bashrc" ]; then alias_file="$HOME/.bashrc";
        elif [ -f "$HOME/.bash_profile" ]; then alias_file="$HOME/.bash_profile";
        else return; fi # Do nothing if no config file found
    fi

    local script_alias_name="createdp" # The name for the new alias

    # Check if the alias already exists
    if grep -q -E "^[[:space:]]*alias[[:space:]]+${script_alias_name}=" "$alias_file"; then
        # Alias exists, do nothing.
        return
    fi
    
    # Get the absolute path to this script
    local this_script_path
    this_script_path=$(realpath "${BASH_SOURCE[0]}")
    if [ ! -f "$this_script_path" ]; then
        gum style --foreground="yellow" "Warning: Could not determine absolute path for the script alias."
        return
    fi

    echo ""
    if gum confirm "Create a permanent alias '$(gum style --bold $script_alias_name)' to run this script from anywhere?" --default=true; then
        gum format -- " - Adding alias for this script to **$alias_file**..."
        cat << EOF_ALIAS >> "$alias_file"

# Alias for the DAV Data Project Creator script
# Allows running the project creator from any directory.
alias ${script_alias_name}='source "$this_script_path"'
EOF_ALIAS

        gum style --border double --padding "1" --border-foreground "green" \
            "Alias '$script_alias_name' added successfully!" \
            "To use it, run: $(gum style --bold 'source '$alias_file') or open a new terminal." \
            "You can then run the script by just typing: $(gum style --bold '$script_alias_name')"
    fi
}


if $ADD_QGIS; then
  SHOULD_LAUNCH_QGIS=false
  if $INTERACTIVE_MODE; then
    if gum confirm "Do you want to try launching QGIS with the new project file '$QGIS_PROJ_FILE_ABS'?"; then
      SHOULD_LAUNCH_QGIS=true
    fi
  fi
  if $SHOULD_LAUNCH_QGIS; then
    OS_TYPE=$(uname -s); LAUNCHED=false; QGIS_OPEN_TARGET="$QGIS_PROJ_FILE_ABS"
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        if command -v open >/dev/null 2>&1; then echo "Launching QGIS ('open')..."; open "$QGIS_OPEN_TARGET" &>/dev/null & LAUNCHED=true;
        else gum style --foreground="yellow" "Warning: 'open' command not found."; fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        if command -v xdg-open >/dev/null 2>&1; then echo "Launching QGIS ('xdg-open')..."; xdg-open "$QGIS_OPEN_TARGET" &>/dev/null & LAUNCHED=true;
        elif command -v qgis >/dev/null 2>&1; then echo "Launching QGIS ('qgis')..."; qgis "$QGIS_OPEN_TARGET" &>/dev/null & LAUNCHED=true;
        else gum style --foreground="yellow" "Warning: 'xdg-open' or 'qgis' not found."; fi
    else gum style --foreground="yellow" "Warning: Unsupported OS for QGIS auto-launch."; fi
    if ! $LAUNCHED; then gum style --foreground="yellow" "Could not auto-launch QGIS. Open manually: $(gum style --bold "$QGIS_OPEN_TARGET")"; fi
  fi
fi

if $ADD_R; then
  OPEN_WITH=""
  if $INTERACTIVE_MODE; then
    echo ""; OPEN_WITH=$(gum choose "RStudio" "VSCode/Cursor" "Neither" --header "Open R project ($PROJECT_NAME_FOR_FILES.Rproj) with:" --height "$GUM_CHOOSE_HEIGHT")
  fi

  if [ -n "$OPEN_WITH" ]; then
    R_OPEN_TARGET_FILE="$RPROJ_FILE_ABS"; R_OPEN_TARGET_DIR="$PROJECT_ROOT_DIR"
    case "$OPEN_WITH" in
      "RStudio") OS_TYPE=$(uname -s); LAUNCH_CMD=""
        if [[ "$OS_TYPE" == "Darwin" ]]; then LAUNCH_CMD="open"; elif [[ "$OS_TYPE" == "Linux" ]]; then LAUNCH_CMD="xdg-open"; fi
        if [[ -n "$LAUNCH_CMD" ]] && command -v "$LAUNCH_CMD" >/dev/null 2>&1; then
          echo "Launching R project ('$LAUNCH_CMD')..."; "$LAUNCH_CMD" "$R_OPEN_TARGET_FILE" &>/dev/null &
        elif command -v rstudio >/dev/null 2>&1; then echo "Launching R project ('rstudio')..."; rstudio "$R_OPEN_TARGET_FILE" &>/dev/null &
        else gum style --foreground="yellow" "Warning: Could not find command to open R project."; fi ;;
      "VSCode/Cursor") EDITOR_CMD=""
        if command -v cursor >/dev/null 2>&1; then EDITOR_CMD="cursor"; elif command -v code >/dev/null 2>&1; then EDITOR_CMD="code"; fi
        if [[ -n "$EDITOR_CMD" ]]; then echo "Launching $EDITOR_CMD in '$R_OPEN_TARGET_DIR'..."
          "$EDITOR_CMD" "$R_OPEN_TARGET_DIR" &>/dev/null &
        else gum style --foreground="yellow" "Warning: Neither 'cursor' nor 'code' found."; fi ;;
      "Neither") echo "Okay, not opening any editor for the R project.";;
      *) echo "No editor selected for R project.";;
    esac
  fi
fi

SUMMARY_MSG="Project setup complete with common directories."
COMPONENT_SUMMARY=""
if $ADD_R; then COMPONENT_SUMMARY="$COMPONENT_SUMMARY R,"; fi
if $ADD_QGIS; then COMPONENT_SUMMARY="$COMPONENT_SUMMARY QGIS,"; fi
if $ADD_QUARTO; then COMPONENT_SUMMARY="$COMPONENT_SUMMARY Quarto,"; fi

if [ -n "$COMPONENT_SUMMARY" ]; then
    COMPONENT_SUMMARY=$(echo "${COMPONENT_SUMMARY%,}" | sed 's/,/, /g' | sed 's/\(.*\), \(.*\)/\1 and \2/') # Oxford comma friendly
    SUMMARY_MSG="Project setup complete with $COMPONENT_SUMMARY and common directories."
else
    SUMMARY_MSG="Basic project structure and Git repo created. No specific R, QGIS, or Quarto components added."
fi

print_success_dpc "$SUMMARY_MSG" "$PROJECT_ROOT_DIR"
echo ""; gum style --italic "Created project structure (top level):"
if command -v tree >/dev/null 2>&1; then
    tree -L 2 -a -I ".git|.Rproj.user|.venv|__pycache__|.DS_Store|.quarto" "$PROJECT_ROOT_DIR"
else
  gum style --faint " (tree command not found, showing basic ls instead)"
  ls -Ap "$PROJECT_ROOT_DIR" | sed 's:^:  :'
  if [ -d "$PROJECT_ROOT_DIR/data_raw/geodata" ]; then
      echo "data_raw/geodata structure:"; ls -Ap "$PROJECT_ROOT_DIR/data_raw/geodata" | sed 's:^:    :';
  fi
fi
echo ""; echo "Current directory: $(pwd)"
gum style --faint "(Tip: If you ran with 'source $0' or '. $0', you are now in the project directory.)"
gum style --faint "Config key '$THIS_SCRIPT_CONFIG_KEY_BASE_PROJECT_DIR' in shared config file: $DAV_CONFIG_FILE"
return 0