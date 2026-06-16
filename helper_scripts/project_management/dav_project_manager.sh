#!/usr/bin/env bash

# DAV Project Manager
# A centralized function to manage and open projects

# Configuration
PROJECTS_CONFIG_FILE="$HOME/.config/dav/projects.json"
PROJECTS_BASE_DIR="$HOME/projects"
RAYCAST_SCRIPTS_DIR="$HOME/Documents/raycast_shell_command"

# Store the script path at source-time so dav_projects() can reload itself
if [ -n "$ZSH_VERSION" ]; then
    _DAV_PM_SCRIPT_PATH="${(%):-%x}"
else
    _DAV_PM_SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
_DAV_PM_MTIME=$(stat -f %m "$_DAV_PM_SCRIPT_PATH" 2>/dev/null || stat -c %Y "$_DAV_PM_SCRIPT_PATH" 2>/dev/null)

# Ensure config directory exists
mkdir -p "$(dirname "$PROJECTS_CONFIG_FILE")"

# Initialize projects config if it doesn't exist
init_projects_config() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        cat > "$PROJECTS_CONFIG_FILE" << 'EOF'
{
  "projects": []
}
EOF
    fi
}

# Add a project to the config
add_project() {
    local project_name="$1"
    local project_path="$2"

    # Ensure the config file exists and is valid, or initialize it
    if ! jq -e . >/dev/null 2>&1 "$PROJECTS_CONFIG_FILE"; then
        echo '{"projects":[]}' > "$PROJECTS_CONFIG_FILE"
    fi

    # Check if project name already exists
    if jq -e --arg name "$project_name" '.projects[] | select(.name == $name)' "$PROJECTS_CONFIG_FILE" > /dev/null 2>&1; then
        echo "Project '$project_name' already exists!"
        return 1
    fi

    # Find project files
    local r_proj_file; r_proj_file=$(find "$project_path" -maxdepth 1 -name "*.Rproj" -print -quit)
    local qgs_file; qgs_file=$(find "$project_path" -maxdepth 1 -name "*.qgs" -print -quit)

    # Create the new project entry as a JSON string
    local new_project_json;
    new_project_json=$(jq -n \
        --arg name "$project_name" \
        --arg path "$project_path" \
        --arg r_proj "$r_proj_file" \
        --arg qgs "$qgs_file" \
        '{name: $name, path: $path, r_proj_file: $r_proj, qgs_file: $qgs}')

    # Read current config, add the new project to it in memory
    local updated_config
    updated_config=$(jq --argjson new_project "$new_project_json" '.projects += [$new_project]' "$PROJECTS_CONFIG_FILE")

    # Check if the update was successful and produced valid JSON before writing to the file
    if echo "$updated_config" | jq -e . >/dev/null 2>&1; then
        echo "$updated_config" > "$PROJECTS_CONFIG_FILE"
        echo "Added project: $project_name"
    else
        echo "Error: Failed to add project. The configuration file might be corrupt."
        return 1
    fi
}

# Remove a project from the config
remove_project() {
    local project_name="$1"

    if ! jq -e --arg name "$project_name" '.projects[] | select(.name == $name)' "$PROJECTS_CONFIG_FILE" > /dev/null 2>&1; then
        echo "Project '$project_name' not found."
        return 1
    fi

    local updated_config
    updated_config=$(jq --arg name "$project_name" 'del(.projects[] | select(.name == $name))' "$PROJECTS_CONFIG_FILE")

    if echo "$updated_config" | jq -e . >/dev/null 2>&1; then
        echo "$updated_config" > "$PROJECTS_CONFIG_FILE"
        echo "Removed project: $project_name"
    else
        echo "Error: Failed to remove project. The configuration file might be corrupt."
        return 1
    fi
}

# List all projects
list_projects() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        echo "No projects configured yet."
        return 1
    fi
    
    jq -r '.projects[] | "\(.name) | \(.path) | \(.type)"' "$PROJECTS_CONFIG_FILE" 2>/dev/null || echo "No projects found."
}

# --- Installation Function ---
# Checks if the project manager is installed in the shell config and offers to install/update it.
_install_or_update_manager() {
    local ZSHRC_FILE="$HOME/.zshrc"
    local ZSHRC_ALIASES_FILE="$HOME/.zshrc-aliases"
    local ALIAS_FILE="$ZSHRC_ALIASES_FILE"
    
    if [ ! -f "$ALIAS_FILE" ]; then
        ALIAS_FILE="$ZSHRC_FILE"
    fi

    # The current, correct path of the script being executed
    local SCRIPT_PATH
    if [ -n "$ZSH_VERSION" ]; then
        SCRIPT_PATH=$(realpath "${(%):-%x}")
    else
        SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
    fi
    
    local OLD_PATH_PATTERN="helper_scripts/dav_project_manager.sh"
    local is_installed=false
    local needs_update=false

    if [ -f "$ALIAS_FILE" ]; then
        # Check if it's installed at all
        if grep -q "dav_project_manager.sh" "$ALIAS_FILE"; then
            is_installed=true
            # Check if it's pointing to the old, incorrect path
            if grep -q "$OLD_PATH_PATTERN" "$ALIAS_FILE"; then
                needs_update=true
            fi
        fi
    fi

    local install_message="It looks like the DAV Project Manager isn't installed in your shell config. This means you have to 'source' it every time you open a new terminal."

    if $needs_update; then
        install_message="A previous version of the DAV Project Manager was found in your shell config. It needs to be updated to the new path."
    fi
    
    if ! $is_installed || $needs_update; then
        if command -v gum >/dev/null 2>&1; then
            gum style --border normal --padding "1 2" --border-foreground 212 "$install_message"
            if gum confirm "Do you want to permanently install/update it in '$ALIAS_FILE'?"; then
                 # Perform the update or install
                if $needs_update; then
                    sed -i.bak "s|source .*/$OLD_PATH_PATTERN|source \"$SCRIPT_PATH\"|g" "$ALIAS_FILE"
                    gum style --foreground green "✅ Update complete! Your shell config has been updated."
                else
                    echo -e "\n# --- DAV Project Manager ---\nif [ -f \"$SCRIPT_PATH\" ]; then\n    source \"$SCRIPT_PATH\"\nfi" >> "$ALIAS_FILE"
                    gum style --foreground green "✅ Installation complete! The project manager has been added to your shell config."
                fi
                gum style --foreground yellow "Please open a new terminal or run 'source $ALIAS_FILE' to apply the changes."
            fi
        else
            echo "$install_message"
            read -r -p "Permanently install/update it in '$ALIAS_FILE'? [Y/n] " response
            if [[ ! "$response" =~ ^[Nn]$ ]]; then
                if $needs_update; then
                    sed -i.bak "s|source .*/$OLD_PATH_PATTERN|source \"$SCRIPT_PATH\"|g" "$ALIAS_FILE"
                    echo "✅ Update complete!"
                else
                    echo -e "\n# --- DAV Project Manager ---\nif [ -f \"$SCRIPT_PATH\" ]; then\n    source \"$SCRIPT_PATH\"\nfi" >> "$ALIAS_FILE"
                    echo "✅ Installation complete!"
                fi
                echo "Please open a new terminal or run 'source $ALIAS_FILE' to apply the changes."
            fi
        fi
    else
         if command -v gum >/dev/null 2>&1; then
            gum style --foreground green "✅ Project Manager is already installed and up-to-date."
         else
            echo "✅ Project Manager is already installed and up-to-date."
         fi
    fi
}

# Get project path by name
get_project_path() {
    local project_name="$1"
    jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .path' "$PROJECTS_CONFIG_FILE" 2>/dev/null
}

# Interactive project selection with enhanced UI
select_project() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground="red" --border="normal" --border-foreground="red" --padding="1 2" \
                      "No projects configured yet." \
                      "Run 'pj add' to add your first project!"
        else
            echo "No projects configured yet."
            echo "Run 'pj add' to add your first project!"
        fi
        return 1
    fi
    
    # Get project names with additional info
    local projects_info=$(jq -r '.projects[] | "\(.name) | \(.path)"' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$projects_info" ]; then
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground="red" --border="normal" --border-foreground="red" --padding="1 2" \
                      "No projects found." \
                      "Run 'pj add' to add your first project!"
        else
            echo "No projects found."
            echo "Run 'pj add' to add your first project!"
        fi
        return 1
    fi
    
    # Use fzf if available (best experience), then gum, then fallback
    if command -v fzf >/dev/null 2>&1; then
        local selected=$(echo "$projects_info" | fzf --height=60% --border --header="🎯 Select a project:" --preview="echo 'Project details:' && echo {}" --preview-window=up:3 | cut -d'|' -f1 | xargs)
        [ -z "$selected" ] && return 1
        echo "$selected"
    elif command -v gum >/dev/null 2>&1; then
        local projects=($(echo "$projects_info" | cut -d'|' -f1))
        local selected=$(printf '%s\n' "${projects[@]}" | gum choose --header="🎯 Select a project:" --height=10)
        [ -z "$selected" ] && return 1
        echo "$selected"
    else
        echo "Available projects:"
        local projects=($(echo "$projects_info" | cut -d'|' -f1))
        select project in "${projects[@]}"; do
            [ -n "$project" ] && echo "$project" && break
        done
    fi
}

# Interactive multi-project selection
select_projects() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground="red" --border="normal" --border-foreground="red" --padding="1 2" \
                      "No projects configured yet." \
                      "Run 'pj add' to add your first project!"
        else
            echo "No projects configured yet."
            echo "Run 'pj add' to add your first project!"
        fi
        return 1
    fi
    
    local projects_info=$(jq -r '.projects[] | "\(.name) | \(.path)"' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
    
    if [ -z "$projects_info" ]; then
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground="red" --border="normal" --border-foreground="red" --padding="1 2" \
                      "No projects found." \
                      "Run 'pj add' to add your first project!"
        else
            echo "No projects found."
            echo "Run 'pj add' to add your first project!"
        fi
        return 1
    fi
    
    if command -v fzf >/dev/null 2>&1; then
        # Use awk to trim leading/trailing space from the name part
        local selected=$(echo "$projects_info" | fzf -m --bind 'space:toggle+down' --height=60% --border --header="🎯 Select projects (SPACE to select multiple):" --preview="echo 'Project details:' && echo {}" --preview-window=up:3 | cut -d'|' -f1 | awk '{$1=$1};1')
        [ -z "$selected" ] && return 1
        echo "$selected"
    elif command -v gum >/dev/null 2>&1; then
        # Use awk to trim leading/trailing space
        local selected=$(echo "$projects_info" | cut -d'|' -f1 | awk '{$1=$1};1' | gum choose --no-limit --header="🎯 Select projects:" --height=10)
        [ -z "$selected" ] && return 1
        echo "$selected"
    else
        select_project
    fi
}

# Multi-select application selection
select_applications() {
    local project_name="$1"
    local project_path="$2"
    
    # Check what's available in the project
    local available_apps=()
    local app_descriptions=()
    
    # Always available
    command -v cursor >/dev/null 2>&1 && available_apps+=("cursor") && app_descriptions+=("🖱️  Cursor")
    command -v code   >/dev/null 2>&1 && available_apps+=("code")   && app_descriptions+=("📝 VS Code")

    available_apps+=("terminal")
    app_descriptions+=("💻 Terminal (cd to project)")
    
    # --- Check for available project files from config ---
    # Check for RStudio Project
    local r_proj_found=false
    if [ -n "$project_name" ]; then
        local r_proj_file; r_proj_file=$(jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .r_proj_file' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
        if [ -n "$r_proj_file" ] && [ "$r_proj_file" != "null" ] && [ -f "$r_proj_file" ]; then
            available_apps+=("r")
            app_descriptions+=("📊 RStudio (.Rproj)")
            r_proj_found=true
        fi
    fi
    if ! $r_proj_found && [ -n "$project_path" ]; then
        if find "$project_path" -maxdepth 1 -name "*.Rproj" -print -quit | grep -q "."; then
            available_apps+=("r")
            app_descriptions+=("📊 RStudio (.Rproj)")
        fi
    fi

    # Check for QGIS Project
    local qgs_found=false
    if [ -n "$project_name" ]; then
        local qgs_file; qgs_file=$(jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .qgs_file' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
        if [ -n "$qgs_file" ] && [ "$qgs_file" != "null" ] && [ -f "$qgs_file" ]; then
            available_apps+=("qgis")
            app_descriptions+=("🗺️  QGIS (.qgs)")
            qgs_found=true
        fi
    fi
    if ! $qgs_found && [ -n "$project_path" ]; then
        if find "$project_path" -maxdepth 1 -name "*.qgs" -print -quit | grep -q "."; then
            available_apps+=("qgis")
            app_descriptions+=("🗺️  QGIS (.qgs)")
        fi
    fi
    
    # Use gum for multi-select if available
    if command -v gum >/dev/null 2>&1; then
        # We need to get the app key back from the selection.
        local selected_descriptions
        selected_descriptions=$(printf '%s\n' "${app_descriptions[@]}" | gum choose --no-limit --header="🚀 How do you want to open '$project_name'?" --height=8)
        [ -z "$selected_descriptions" ] && return 1

        local selected_apps=()
        while IFS= read -r desc; do
            local i=0
            while [[ $i -lt ${#app_descriptions[@]} ]]; do
                if [[ "${app_descriptions[$i]}" == "$desc" ]]; then
                    selected_apps+=("${available_apps[$i]}")
                    break
                fi
                ((i++))
            done
        done <<< "$selected_descriptions"

        [ ${#selected_apps[@]} -eq 0 ] && return 1
        printf '%s\n' "${selected_apps[@]}"
    else
        # Fallback to single selection
        echo "How do you want to open '$project_name'?"
        select app in "${available_apps[@]}"; do
            [ -n "$app" ] && echo "$app" && break
        done
    fi
}

# Open project with specified application
open_project() {
    local project_name="$1"
    local app_type="$2"
    
    local project_path=$(get_project_path "$project_name")
    
    if [ -z "$project_path" ]; then
        echo "Project '$project_name' not found!"
        return 1
    fi
    
    if [ ! -d "$project_path" ]; then
        echo "Project directory does not exist: $project_path"
        return 1
    fi
    
    case "$app_type" in
        "cursor")
            if command -v cursor >/dev/null 2>&1; then
                cursor "$project_path" &
            else
                echo "Cursor not found!"
                return 1
            fi
            ;;
        "code")
            if command -v code >/dev/null 2>&1; then
                code "$project_path" &
            else
                echo "VS Code (code) not found!"
                return 1
            fi
            ;;
        "r"|"rstudio")
            local r_proj_file
            r_proj_file=$(jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .r_proj_file' "$PROJECTS_CONFIG_FILE" 2>/dev/null)

            # Fallback for older entries or if config is weird: find the file
            if [ -z "$r_proj_file" ] || [ "$r_proj_file" = "null" ]; then
                 r_proj_file=$(find "$project_path" -maxdepth 1 -name "*.Rproj" -type f | head -1)
            fi

            if [ -n "$r_proj_file" ] && [ -f "$r_proj_file" ]; then
                if command -v open >/dev/null 2>&1; then
                    echo "Opening RStudio project: $r_proj_file"
                    open "$r_proj_file" &
                else
                    echo "Cannot open .Rproj file: $r_proj_file"
                fi
            else
                echo "No .Rproj file found in project directory or config"
                return 1
            fi
            ;;
        "qgis")
            # New method: Use the direct path from config if available
            local qgs_file
            qgs_file=$(jq -r --arg name "$project_name" '.projects[] | select(.name == $name) | .qgs_file' "$PROJECTS_CONFIG_FILE" 2>/dev/null)

            # Fallback for older entries: find the file
            if [ -z "$qgs_file" ] || [ "$qgs_file" = "null" ]; then
                 qgs_file=$(find "$project_path" -maxdepth 1 -name "*.qgs" -type f | head -1)
            fi

            if [ -n "$qgs_file" ] && [ -f "$qgs_file" ]; then
                if command -v qgis >/dev/null 2>&1; then
                    qgis "$qgs_file" &
                elif command -v open >/dev/null 2>&1; then
                    (open -a QGIS "$qgs_file" 2>/dev/null || open -a QGIS-LTR "$qgs_file" 2>/dev/null || open "$qgs_file") &
                else
                    echo "Cannot open .qgs file: $qgs_file. Neither 'qgis' nor 'open' command is available."
                    return 1
                fi
            else
                echo "No .qgs file found in project directory"
                return 1
            fi
            ;;
        "terminal"|"cd")
            cd "$project_path"
            ;;
        *)
            echo "Unknown application type: $app_type"
            echo "Available types: code, r, rstudio, qgis, terminal, cd"
            return 1
            ;;
    esac
}

# Interactive project opening with multi-select
interactive_open() {
    # Select project
    local project_name=$(select_project)
    [ -z "$project_name" ] && return 1
    
    local project_path=$(get_project_path "$project_name")
    
    # Select applications (multi-select)
    local selected_apps=($(select_applications "$project_name" "$project_path"))
    [ ${#selected_apps[@]} -eq 0 ] && return 1
    
    # Open apps in a fixed order with delays to prevent screen-jumping
    local app_order=("terminal" "cd" "code" "cursor" "r" "rstudio" "qgis")
    local app_delays=(4 4 5 5 6 6 0)
    local opened_count=0

    for ((i = 0; i < ${#app_order[@]}; i++)); do
        local ordered_app="${app_order[$i]}"
        local delay="${app_delays[$i]}"
        for app in "${selected_apps[@]}"; do
            if [[ "$app" == "$ordered_app" ]]; then
                if (( opened_count > 0 )) && (( delay > 0 )); then
                    sleep "$delay"
                fi
                if command -v gum >/dev/null 2>&1; then
                    gum style --foreground="blue" "Opening with $app..."
                else
                    echo "Opening with $app..."
                fi
                open_project "$project_name" "$app"
                opened_count=$((opened_count + 1))
                break
            fi
        done
    done
    
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground="green" --border="normal" --border-foreground="green" --padding="1 2" \
                  "✅ Project '$project_name' opened successfully!"
    else
        echo "✅ Project '$project_name' opened successfully!"
    fi
}

# Sync projects to Raycast script commands (one .sh per project)
raycast_sync() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        echo "No projects configured yet."
        return 1
    fi

    mkdir -p "$RAYCAST_SCRIPTS_DIR"

    # Remove previously generated project scripts
    find "$RAYCAST_SCRIPTS_DIR" -maxdepth 1 -name "dst-*.sh" -delete 2>/dev/null
    find "$RAYCAST_SCRIPTS_DIR" -maxdepth 1 -name "ndr-*.sh" -delete 2>/dev/null
    find "$RAYCAST_SCRIPTS_DIR" -maxdepth 1 -name "personal-*.sh" -delete 2>/dev/null
    find "$RAYCAST_SCRIPTS_DIR" -maxdepth 1 -name "pj-open-*.sh" -delete 2>/dev/null
    find "$RAYCAST_SCRIPTS_DIR" -maxdepth 1 -name "app-*.sh"     -delete 2>/dev/null

    # Declare loop-scoped vars once, OUTSIDE the loop. In zsh, `local foo`
    # on a variable that already has a value (next iteration) prints `foo=val`
    # like `typeset` would — so we'd see stray `category=…` lines everywhere.
    local count=0 category="" slug="" script_file="" title="" rproj_file="" qgs_file=""
    while IFS=$'\t' read -r name proj_path; do
        case "$proj_path" in
            */projects/dst/*)      category="dst" ;;
            */projects/ndr/*)      category="ndr" ;;
            */projects/personal/*) category="personal" ;;
            *)                     category="pj" ;;
        esac

        slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
        script_file="$RAYCAST_SCRIPTS_DIR/${category}-${slug}.sh"
        title="${category} ${name}"

        rproj_file=$(find "$proj_path" -maxdepth 1 -name "*.Rproj" -print -quit 2>/dev/null)
        qgs_file=$(find "$proj_path" -maxdepth 1 -name "*.qgs" -print -quit 2>/dev/null)

        cat > "$script_file" << 'SCRIPT_EOF'
#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title RAYCAST_TITLE_PLACEHOLDER
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📊
# @raycast.packageName DAV Projects

# Documentation:
# @raycast.author Robin

PROJ="PROJ_PLACEHOLDER"
RPROJ="RPROJ_PLACEHOLDER"
QGS="QGS_PLACEHOLDER"
NAME="NAME_PLACEHOLDER"
BASENAME=$(basename "$PROJ")

# ── helpers ──────────────────────────────────────────────────────────────────
# Cursor / VS Code spawn one "extension-host (user) <basename> [n-n]" per
# open workspace — reliable signal that doesn't need Accessibility permission.
_editor_has_project() {
  local app="$1"  # "Cursor" or "Code"
  ps -eo command 2>/dev/null \
    | grep -F "$app Helper (Plugin)" \
    | grep -qE "extension-host[^[:space:]]*[[:space:]]\\([^)]+\\)[[:space:]]${BASENAME}[[:space:]]+\\["
}

# RStudio runs an rsession per project; its cwd points into the project dir.
_rstudio_has_project() {
  [ -f "$RPROJ" ] || return 1
  local pid
  for pid in $(pgrep -f rsession 2>/dev/null); do
    local cwd
    cwd=$(lsof -p "$pid" 2>/dev/null | awk '$4 == "cwd" {print $NF; exit}')
    [[ "$cwd" == "$PROJ"* ]] && return 0
  done
  return 1
}

# QGIS: check lsof for the .qgs file being open by a QGIS process.
_qgis_has_project() {
  [ -f "$QGS" ] || return 1
  lsof -c QGIS 2>/dev/null | grep -qF "$QGS"
}

CURSOR_OPEN=false; VSCODE_OPEN=false; RSTUDIO_OPEN=false; QGIS_OPEN=false
_editor_has_project "Cursor" && CURSOR_OPEN=true
_editor_has_project "Code"   && VSCODE_OPEN=true
_rstudio_has_project         && RSTUDIO_OPEN=true
_qgis_has_project            && QGIS_OPEN=true

# ── 1. Already open somewhere → switch to it (Cursor preferred) ──────────────
# Re-invoking `cursor <path>` / `code <path>` is the canonical way to focus the
# existing window without needing Accessibility permission.
if $CURSOR_OPEN; then
  cursor "$PROJ"
  echo "Cursor ↑ $NAME"
  exit 0
elif $VSCODE_OPEN; then
  code "$PROJ"
  echo "VS Code ↑ $NAME"
  exit 0
elif $RSTUDIO_OPEN; then
  open "$RPROJ"
  echo "RStudio ↑ $NAME"
  exit 0
elif $QGIS_OPEN; then
  open "$QGS"
  echo "QGIS ↑ $NAME"
  exit 0
fi

# ── 2. Not open anywhere → multi-select dialog (open in 1+ apps) ─────────────
# Build the app list dynamically so RStudio/QGIS only show when relevant files exist.
APP_LIST='"Cursor"'
command -v code >/dev/null 2>&1 && APP_LIST="$APP_LIST, \"VS Code\""
[ -f "$RPROJ" ]                 && APP_LIST="$APP_LIST, \"RStudio\""
[ -f "$QGS"   ]                 && APP_LIST="$APP_LIST, \"QGIS\""

# JXA forces the dialog to the foreground via AppKit — AppleScript's
# `tell me to activate` is unreliable when launched from Raycast's background shell.
CHOICES=$(osascript -l JavaScript <<JXA
ObjC.import('AppKit');
\$.NSApplication.sharedApplication.activateIgnoringOtherApps(true);
var app = Application.currentApplication();
app.includeStandardAdditions = true;
var picked;
try {
  picked = app.chooseFromList([${APP_LIST}], {
    withPrompt: '${NAME} — open in:',
    defaultItems: ['Cursor'],
    multipleSelectionsAllowed: true
  });
} catch (e) { picked = false; }
if (picked === false || picked === null) ''; else picked.join('\\n');
JXA
)

[ -z "$CHOICES" ] && { echo "Cancelled"; exit 0; }

opened=""
while IFS= read -r choice; do
  case "$choice" in
    # Cursor/code CLIs often block until the window is ready — background so every
    # selected app in this loop actually runs. (Keep these arms multi-line: `cmd &;`
    # on one line is a bash syntax error inside case.)
    "Cursor")
      cursor "$PROJ" &
      opened="$opened Cursor"
      ;;
    "VS Code")
      code "$PROJ" &
      opened="$opened VS-Code"
      ;;
    "RStudio") open   "$RPROJ" 2>/dev/null; opened="$opened RStudio" ;;
    "QGIS")    open -a QGIS "$QGS" 2>/dev/null \
            || open -a QGIS-LTR "$QGS" 2>/dev/null \
            || open "$QGS"
               opened="$opened QGIS" ;;
  esac
done <<< "$CHOICES"

echo "Opened →$opened $NAME"
SCRIPT_EOF

        sed -i '' \
            -e "s|RAYCAST_TITLE_PLACEHOLDER|${title}|" \
            -e "s|RPROJ_PLACEHOLDER|${rproj_file}|" \
            -e "s|QGS_PLACEHOLDER|${qgs_file}|" \
            -e "s|PROJ_PLACEHOLDER|${proj_path}|" \
            -e "s|NAME_PLACEHOLDER|${name}|" \
            "$script_file"
        chmod +x "$script_file"

        # ── Per-app speed shortcuts: `c <name>`, `r <name>`, `q <name>` ───────
        # No detection, no dialog — just open instantly in the named app.
        # Reinvoking cursor/code on an already-open project just focuses the
        # existing window, so this is safe for both first-open and switch.
        _write_app_shortcut() {
            local letter="$1" icon="$2" cmd="$3" target="$4"
            local f="$RAYCAST_SCRIPTS_DIR/app-${letter}-${slug}.sh"
            cat > "$f" << SHORTCUT_EOF
#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title ${letter} ${name}
# @raycast.mode compact
# @raycast.icon ${icon}
# @raycast.packageName DAV Projects

${cmd} "${target}" 2>/dev/null && echo "${letter} → ${name}"
SHORTCUT_EOF
            chmod +x "$f"
        }

        _write_app_shortcut "c" "💻" "cursor" "$proj_path"
        [ -f "$rproj_file" ] && _write_app_shortcut "r" "📊" "open"   "$rproj_file"
        [ -f "$qgs_file"   ] && _write_app_shortcut "q" "🗺️"  "open -a QGIS" "$qgs_file"

        count=$((count + 1))
    done < <(jq -r '.projects[] | [.name, .path] | @tsv' "$PROJECTS_CONFIG_FILE")

    # Fuzzy pickers for hotkeys — always refresh from repo
    local _rh
    _rh="$(cd "$(dirname "$_DAV_PM_SCRIPT_PATH")" && pwd)/../raycast"
    for _f in dav_raycast_pick_cursor.sh dav_raycast_pick_rstudio.sh dav_raycast_pick_vscode.sh dav_raycast_pick_qgis.sh; do
        [ -f "$_rh/$_f" ] && cp "$_rh/$_f" "$RAYCAST_SCRIPTS_DIR/$_f" && chmod +x "$RAYCAST_SCRIPTS_DIR/$_f"
    done

    if command -v gum >/dev/null 2>&1; then
        gum style --foreground="green" "✅ Synced $count projects → $RAYCAST_SCRIPTS_DIR"
    else
        echo "✅ Synced $count projects → $RAYCAST_SCRIPTS_DIR"
    fi
    cat <<EOM
Raycast commands per project:
  • <category> <name>  smart open: switch if running, else multi-select dialog
  • c <name>           instant Cursor
  • r <name>           instant RStudio  (only when .Rproj exists)
  • q <name>           instant QGIS     (only when .qgs exists)
Optional hotkeys: DAV Pick Cursor / DAV Pick RStudio / DAV Pick VS Code / DAV Pick QGIS (Raycast → Extensions).
EOM
}

# List all projects sorted by last modification time (oldest first).
# Uses only directory mtime — no file scanning, instant.
# Label format is always "AGE  name" (e.g. "2m  geospherer").
# The name is recovered by stripping the age prefix, so no index arrays needed.
clean_projects() {
    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        echo "No projects configured yet."
        return 1
    fi

    local now; now=$(date +%s)
    local tmp; tmp=$(mktemp)

    while IFS=$'\t' read -r name proj_path; do
        local mtime; mtime=$(stat -f %m "$proj_path" 2>/dev/null \
            || stat -c %Y "$proj_path" 2>/dev/null || echo "$now")
        local days=$(( (now - mtime) / 86400 ))
        local label
        if   [ "$days" -ge 365 ]; then label=$(printf "%dy  %s" $((days/365)) "$name")
        elif [ "$days" -ge 30  ]; then label=$(printf "%dm  %s" $((days/30))  "$name")
        else                           label=$(printf "%dd  %s" "$days"       "$name")
        fi
        printf '%s\t%s\n' "$days" "$label" >> "$tmp"
    done < <(jq -r '.projects[] | [.name, .path] | @tsv' "$PROJECTS_CONFIG_FILE" 2>/dev/null)

    if [ ! -s "$tmp" ]; then
        echo "No projects found."
        rm -f "$tmp"
        return 1
    fi

    # Sort by age descending (oldest first), keep only the label column
    local sorted_labels; sorted_labels=$(sort -rn "$tmp" | cut -f2)
    rm -f "$tmp"

    local selected
    if command -v gum >/dev/null 2>&1; then
        selected=$(echo "$sorted_labels" | \
            gum choose --no-limit --header "Select projects to remove (sorted oldest first):")
        [ -z "$selected" ] && return 0
    else
        echo "Projects (oldest first):"
        echo "$sorted_labels" | sed 's/^/  /'
        echo ""
        read -r -p "Enter project names to remove (space-separated): " manual_input
        [ -z "$manual_input" ] && return 0
        for name in $manual_input; do remove_project "$name"; done
        return 0
    fi

    # Recover name from label by stripping the leading age token ("2m  " / "76d  ")
    while IFS= read -r sel; do
        [ -z "$sel" ] && continue
        local name; name=$(echo "$sel" | sed 's/^[^ ]*  //')
        [ -n "$name" ] && remove_project "$name"
    done <<< "$selected"
}

# Main project manager function
dav_projects() {
    # --- Auto-reload if the script file has changed ---
    local _mtime_now
    _mtime_now=$(stat -f %m "$_DAV_PM_SCRIPT_PATH" 2>/dev/null || stat -c %Y "$_DAV_PM_SCRIPT_PATH" 2>/dev/null)
    if [[ "$_mtime_now" != "$_DAV_PM_MTIME" ]]; then
        export _DAV_PM_MTIME="$_mtime_now"
        source "$_DAV_PM_SCRIPT_PATH"
        dav_projects "$@"
        return
    fi

    # --- Auto-install/update check ---
    # This runs once per shell session to ensure the script is properly installed.
    : "${_DAV_PJ_INSTALL_CHECK_COMPLETE:=}"
    if [[ -z "$_DAV_PJ_INSTALL_CHECK_COMPLETE" ]]; then
        local ZSHRC_ALIASES_FILE="$HOME/.zshrc-aliases"
        local ALIAS_FILE="${ZSHRC_ALIASES_FILE}"
        [ ! -f "$ALIAS_FILE" ] && ALIAS_FILE="$HOME/.zshrc"

        if ! grep -q "dav_project_manager.sh" "$ALIAS_FILE" 2>/dev/null; then
            _install_or_update_manager
        fi
        export _DAV_PJ_INSTALL_CHECK_COMPLETE=true
    fi

    init_projects_config
    
    local action="$1"
    
    case "$action" in
        "install")
            _install_or_update_manager
            ;;
        "raycast-sync")
            raycast_sync
            ;;
        "clean")
            clean_projects
            ;;
        "add")
            local project_path

            # Case 1: Path is provided as an argument `pj add <dir>`
            if [ $# -eq 2 ]; then
                project_path="$2"
            # Case 2: No path provided `pj add`, so we ask for it.
            elif [ $# -eq 1 ]; then
                if command -v gum >/dev/null 2>&1; then
                    project_path=$(gum input --header "📁 Project path:" --value "$(pwd)")
                    [ -z "$project_path" ] && return 1
                else
                    read -r -p "Project path [$(pwd)]: " project_path
                    project_path=${project_path:-$(pwd)}
                fi
            # Case 3: Old manual mode `pj add <name> <path> <type>` for backwards compatibility/scripting
            elif [ $# -ge 4 ]; then
                    add_project "$2" "$3" "${4:-mixed}"
                    return
            else
                echo "Invalid arguments for 'add'. Use 'pj add <directory>' or just 'pj add' for interactive mode."
                return 1
            fi
            
            # --- Common logic for cases 1 & 2 ---

            # Normalize path
            project_path="${project_path/#\~/$HOME}"
            project_path=$(realpath "$project_path" 2>/dev/null)
            if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
                echo "Error: Directory not found or is invalid: $2"
                return 1
            fi
            
            # Prompt for project name, suggesting the directory name
            local default_name=$(basename "$project_path")
            local project_name
            if command -v gum >/dev/null 2>&1; then
                    project_name=$(gum input --header "📝 Project name:" --value "$default_name")
                    [ -z "$project_name" ] && return 1
            else
                    read -r -p "Project name [$default_name]: " project_name
                    project_name=${project_name:-$default_name}
                    if [ -z "$project_name" ]; then echo "Error: Project name cannot be empty."; return 1; fi
            fi
            
            # Add the project
            add_project "$project_name" "$project_path"
            ;;
        "remove")
            local project_to_remove="$2"
            local projects_list=""

            if [ -n "$project_to_remove" ]; then
                projects_list="$project_to_remove"
            else
                projects_list=$(select_projects)
                [ -z "$projects_list" ] && return 1
            fi
            
            if command -v gum >/dev/null 2>&1; then
                echo "Projects to remove:"
                echo "$projects_list" | sed 's/^/  - /'
                if ! gum confirm "Are you sure you want to remove these projects?"; then
                    return 0
                fi
            else
                echo "Projects to remove:"
                echo "$projects_list" | sed 's/^/  - /'
                read -r -p "Are you sure you want to remove these projects? [y/N] " response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    return 0
                fi
            fi

            while IFS= read -r project; do
                [ -z "$project" ] && continue
                remove_project "$project"
            done <<< "$projects_list"
            ;;
        "list")
            if command -v gum >/dev/null 2>&1; then
                local projects_info
                projects_info=$(jq -r '.projects[] | "\(.name)|\(.path)"' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
                if [ -n "$projects_info" ]; then
                    gum style --foreground="cyan" --border="normal" --border-foreground="cyan" --padding="1 2" \
                              "📋 Your Projects"
                    echo "$projects_info" | while IFS='|' read -r name proj_path; do
                        gum style --foreground="blue" "• $name"
                        gum style --foreground="gray" "  📁 $proj_path"
                        echo ""
                    done
                else
                    gum style --foreground="red" --border="normal" --border-foreground="red" --padding="1 2" \
                              "No projects found." \
                              "Run 'pj add' to add your first project!"
                fi
            else
                list_projects
            fi
            ;;
        "open")
            local project_name="$2"
            local app_type="$3"
            
            # If no project specified, let user select
            if [ -z "$project_name" ]; then
                project_name=$(select_project)
                [ -z "$project_name" ] && return 1
            fi

            # --- New Logic: Resolve path to project name ---
            # Check if the provided "name" is actually a path
            if [ -d "$project_name" ]; then
                local resolved_path
                resolved_path=$(realpath "$project_name")
                
                # Find the project name from the config that matches this path
                local name_from_path
                name_from_path=$(jq -r --arg path "$resolved_path" '.projects[] | select(.path == $path) | .name' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
                
                if [ -n "$name_from_path" ]; then
                    # Found it! Use the correct project name from now on.
                    project_name="$name_from_path"
                fi
            fi
            # --- End New Logic ---
            
            # If no app type specified, let user select
            if [ -z "$app_type" ]; then
                local project_path=$(get_project_path "$project_name")
                local selected_apps=($(select_applications "$project_name" "$project_path"))
                [ ${#selected_apps[@]} -eq 0 ] && return 1
                
                # Open apps in a fixed order with delays to prevent screen-jumping
                local app_order=("terminal" "cd" "code" "cursor" "r" "rstudio" "qgis")
                local app_delays=(0 1 3 4 5 5 0)
                local opened_count=0

                for ((i = 0; i < ${#app_order[@]}; i++)); do
                    local ordered_app="${app_order[$i]}"
                    local delay="${app_delays[$i]}"
                    for app in "${selected_apps[@]}"; do
                        if [[ "$app" == "$ordered_app" ]]; then
                            if (( opened_count > 0 )) && (( delay > 0 )); then
                                sleep "$delay"
                            fi
                            open_project "$project_name" "$app"
                            opened_count=$((opened_count + 1))
                            break
                        fi
                    done
                done
            else
                open_project "$project_name" "$app_type"
            fi
            ;;
        ""|"interactive")
            # Default behavior - fully interactive
            interactive_open
            ;;
        "help"|"-h"|"--help")
            if command -v gum >/dev/null 2>&1; then
                gum style --foreground="cyan" --border="double" --border-foreground="cyan" --padding="1 2" \
                          "🎯 DAV Project Manager" \
                          "Interactive project management with multi-app support"
                echo ""
                gum style --foreground="yellow" "Usage:"
                echo "  pj                           # Interactive project selection and opening"
                echo "  pj install                   # Install/update the project manager in your shell"
                echo "  pj open [project] [app]      # Open specific project with specific app"
                echo "  pj add [directory]           # Add a new project (interactively)"
                echo "  pj remove [project]          # Remove a project"
                echo "  pj list                      # List all projects"
                echo "  pj clean                     # Remove entries whose directories no longer exist"
                echo "  pj raycast-sync              # Sync all projects as Raycast script commands"
                echo "                                # (also installs \"DAV Pick Cursor\" / \"DAV Pick RStudio\" pickers)"
                echo "  pj help                      # Show this help"
                echo ""
                gum style --foreground="yellow" "Application types:"
                echo "  📝 code           - Open in VS Code"
                echo "  📊 r, rstudio    - Open .Rproj file in RStudio"
                echo "  🗺️  qgis          - Open .qgs file in QGIS"
                echo "  💻 terminal, cd  - Change to project directory"
            else
                echo "DAV Project Manager"
                echo ""
                echo "Usage:"
                echo "  dav_projects                       # Interactive project selection and opening"
                echo "  dav_projects install               # Install/update the project manager in your shell"
                echo "  dav_projects open [project] [app]  # Open specific project with specific app"
                echo "  dav_projects add [directory]       # Add a new project (interactively)"
                echo "  dav_projects remove [project]      # Remove a project"
                echo "  dav_projects list                  # List all projects"
                echo "  dav_projects clean                 # Remove entries whose directories no longer exist"
                echo "  dav_projects raycast-sync          # Sync Raycast scripts + fuzzy pickers"
                echo "  dav_projects help                  # Show this help"
                echo ""
                echo "Application types:"
                echo "  code          - Open in VS Code"
                echo "  r, rstudio    - Open .Rproj file in RStudio"
                echo "  qgis          - Open .qgs file in QGIS"
                echo "  terminal, cd  - Change to project directory"
            fi
            ;;
        *)
            echo "Unknown action: $action"
            echo "Use 'pj help' for usage information"
            return 1
            ;;
    esac
}

# Create alias for easier access
alias pj='dav_projects'

# Open a project filtered by category (inferred from path).
# Used by the `dst` and `ndr` shell functions below.
_pj_category_open() {
    local category="$1"   # e.g. "dst" or "ndr"
    local query="$2"

    if [ ! -f "$PROJECTS_CONFIG_FILE" ]; then
        echo "No projects configured."
        return 1
    fi

    # Filter: path must contain /<category>/
    local projects_info
    projects_info=$(jq -r --arg cat "/$category/" \
        '.projects[] | select(.path | contains($cat)) | [.name, .path] | @tsv' \
        "$PROJECTS_CONFIG_FILE" 2>/dev/null)

    if [ -z "$projects_info" ]; then
        echo "No $category projects found in the project list."
        return 1
    fi

    local selected_name selected_path

    if [ -n "$query" ]; then
        # Case-insensitive fuzzy match on name
        local q; q=$(echo "$query" | tr '[:upper:]' '[:lower:]')
        local matches
        matches=$(echo "$projects_info" | awk -F'\t' -v q="$q" 'tolower($1) ~ q')

        if [ -z "$matches" ]; then
            echo "No $category project matching '$query'."
            echo "Available: $(echo "$projects_info" | cut -f1 | tr '\n' '  ')"
            return 1
        fi

        local count; count=$(echo "$matches" | wc -l | tr -d ' ')

        if [ "$count" -eq 1 ]; then
            selected_name=$(echo "$matches" | cut -f1)
            selected_path=$(echo "$matches" | cut -f2)
        else
            # Multiple matches — let user pick
            if command -v fzf >/dev/null 2>&1; then
                local chosen
                chosen=$(echo "$matches" | fzf --delimiter='\t' --with-nth=1 \
                    --query="$query" --select-1 --height=40% --border \
                    --header="Multiple $category matches:")
                [ -z "$chosen" ] && return 1
                selected_name=$(echo "$chosen" | cut -f1)
                selected_path=$(echo "$chosen" | cut -f2)
            elif command -v gum >/dev/null 2>&1; then
                selected_name=$(echo "$matches" | cut -f1 | gum choose --header "Multiple $category matches:")
                [ -z "$selected_name" ] && return 1
                selected_path=$(echo "$matches" | awk -F'\t' -v n="$selected_name" '$1 == n {print $2}')
            else
                selected_name=$(echo "$matches" | head -1 | cut -f1)
                selected_path=$(echo "$matches" | head -1 | cut -f2)
            fi
        fi
    else
        # No query — show full category list interactively
        if command -v fzf >/dev/null 2>&1; then
            local chosen
            chosen=$(echo "$projects_info" | fzf --delimiter='\t' --with-nth=1 \
                --height=40% --border --header="${category} projects:")
            [ -z "$chosen" ] && return 1
            selected_name=$(echo "$chosen" | cut -f1)
            selected_path=$(echo "$chosen" | cut -f2)
        elif command -v gum >/dev/null 2>&1; then
            selected_name=$(echo "$projects_info" | cut -f1 | gum choose --header "${category} projects:")
            [ -z "$selected_name" ] && return 1
            selected_path=$(echo "$projects_info" | awk -F'\t' -v n="$selected_name" '$1 == n {print $2}')
        else
            echo "${category} projects:"
            echo "$projects_info" | cut -f1 | nl
            return 1
        fi
    fi

    [ -z "$selected_path" ] && return 1

    if command -v cursor >/dev/null 2>&1; then
        cursor "$selected_path"
    elif command -v code >/dev/null 2>&1; then
        code "$selected_path"
    else
        open "$selected_path"
    fi
}

function dst() { _pj_category_open "dst" "$1"; }
function ndr() { _pj_category_open "ndr" "$1"; }
