#!/usr/bin/env bash

# DAV Project Manager
# A centralized function to manage and open projects

# Configuration
PROJECTS_CONFIG_FILE="$HOME/.config/dav/projects.json"
PROJECTS_BASE_DIR="$HOME/projects"

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

# Multi-select application selection
select_applications() {
    local project_name="$1"
    local project_path="$2"
    
    # Check what's available in the project
    local available_apps=()
    local app_descriptions=()
    
    # Always available
    available_apps+=("cursor")
    app_descriptions+=("📝 Cursor/VS Code")
    
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
            local i=1
            while [[ $i -le ${#app_descriptions[@]} ]]; do
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
        "cursor"|"code")
            if command -v cursor >/dev/null 2>&1; then
                cursor "$project_path" &
            elif command -v code >/dev/null 2>&1; then
                code "$project_path" &
            else
                echo "Neither Cursor nor VS Code found!"
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
            echo "Available types: cursor, code, r, rstudio, qgis, terminal, cd"
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
    
    # Open with each selected application
    for app in "${selected_apps[@]}"; do
        if command -v gum >/dev/null 2>&1; then
            gum style --foreground="blue" "Opening with $app..."
        else
            echo "Opening with $app..."
        fi
        open_project "$project_name" "$app"
    done
    
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground="green" --border="normal" --border-foreground="green" --padding="1 2" \
                  "✅ Project '$project_name' opened successfully!"
    else
        echo "✅ Project '$project_name' opened successfully!"
    fi
}

# Main project manager function
dav_projects() {
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
            if [ -z "$project_to_remove" ]; then
                project_to_remove=$(select_project)
                [ -z "$project_to_remove" ] && return 1
            fi
            
            if command -v gum >/dev/null 2>&1; then
                if ! gum confirm "Are you sure you want to remove '$project_to_remove'?"; then
                    return 0
                fi
            else
                read -r -p "Are you sure you want to remove '$project_to_remove'? [y/N] " response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    return 0
                fi
            fi

            remove_project "$project_to_remove"
            ;;
        "list")
            if command -v gum >/dev/null 2>&1; then
                local projects_info
                projects_info=$(jq -r '.projects[] | "\(.name)|\(.path)"' "$PROJECTS_CONFIG_FILE" 2>/dev/null)
                if [ -n "$projects_info" ]; then
                    gum style --foreground="cyan" --border="normal" --border-foreground="cyan" --padding="1 2" \
                              "📋 Your Projects"
                    echo "$projects_info" | while IFS='|' read -r name path; do
                        gum style --foreground="blue" "• $name"
                        gum style --foreground="gray" "  📁 $path"
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
                
                # Open with each selected application
                for app in "${selected_apps[@]}"; do
                    open_project "$project_name" "$app"
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
                echo "  pj install                     # Install/update the project manager in your shell"
                echo "  pj open [project] [app]      # Open specific project with specific app"
                echo "  pj add [directory]           # Add a new project (interactively)"
                echo "  pj remove [project]          # Remove a project"
                echo "  pj list                      # List all projects"
                echo "  pj help                      # Show this help"
                echo ""
                gum style --foreground="yellow" "Application types:"
                echo "  📝 cursor, code  - Open in Cursor/VS Code"
                echo "  📊 r, rstudio    - Open .Rproj file in RStudio"
                echo "  🗺️  qgis          - Open .qgs file in QGIS"
                echo "  💻 terminal, cd  - Change to project directory"
            else
                echo "DAV Project Manager"
                echo ""
                echo "Usage:"
                echo "  dav_projects                    # Interactive project selection and opening"
                echo "  dav_projects install            # Install/update the project manager in your shell"
                echo "  dav_projects open [project] [app] # Open specific project with specific app"
                echo "  dav_projects add [directory]      # Add a new project (interactively)"
                echo "  dav_projects remove [project]     # Remove a project"
                echo "  dav_projects list              # List all projects"
                echo "  dav_projects help              # Show this help"
                echo ""
                echo "Application types:"
                echo "  cursor, code  - Open in Cursor/VS Code"
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
