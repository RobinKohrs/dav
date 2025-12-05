#!/usr/bin/env bash

# Simple data project creator with templates
PROJECT_ROOT_DIR_TO_CLEANUP=""
SCRIPT_SUCCESSFUL=false

cleanup() {
  if [ "$SCRIPT_SUCCESSFUL" = false ] && [ -n "$PROJECT_ROOT_DIR_TO_CLEANUP" ] && [ -d "$PROJECT_ROOT_DIR_TO_CLEANUP" ]; then
    echo "Cleaning up..."
    rm -rf "$PROJECT_ROOT_DIR_TO_CLEANUP"
  fi
}
trap cleanup EXIT INT TERM

# Load shared config
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_DIR=$(dirname "${(%):-%x}")
else
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
fi

source "$SCRIPT_DIR/../common/dav_common.sh" || { echo "Config failed"; return 1; }

# Check dependencies
for cmd in gum git realpath date; do
    command -v "$cmd" >/dev/null || { echo "Missing: $cmd"; return 1; }
done

check_dav_config || return 1

echo "=== Data Project Creator ==="

# Template definitions
setup_template() {
    local template="$1"
    BASE_DIR="$HOME/projects"
    YEAR=$(date +%Y)
    # Use date's zero-padded month directly to avoid octal interpretation issues (e.g., 08/09)
    MONTH=$(date +%m)
    
    case "$template" in
        "basic-dst")
            CATEGORY="DST"
            ADD_R=true
            ADD_QGIS=true
            ;;
        "basic-ndr")
            CATEGORY="NDR" 
            ADD_R=true
            ADD_QGIS=true
            ;;
        "basic-personal")
            CATEGORY="Personal"
            ADD_R=false
            ADD_QGIS=false
            ;;
        "r-analysis")
            CATEGORY="Personal"
            ADD_R=true
            ADD_QGIS=false
            ;;
        "geospatial")
            CATEGORY="Personal"
            ADD_R=true
            ADD_QGIS=true
            ;;
        *)
    return 1
            ;;
    esac
    
    PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g')
    CATEGORY_LOWER=$(echo "$CATEGORY" | tr '[:upper:]' '[:lower:]')
    TARGET_DIR="$BASE_DIR/$CATEGORY_LOWER/$YEAR/$MONTH/$YEAR-$MONTH-$PROJECT_SLUG"
    echo "Template: $template -> $TARGET_DIR"
}

# Check for command line template
TEMPLATE_MODE=""
if [ "$#" -ge 1 ]; then
    case "$1" in
        basic-dst|basic-ndr|basic-personal|r-analysis|geospatial)
            TEMPLATE_MODE="$1"
            ;;
    esac
fi

# Get project name and setup
if [ -n "$TEMPLATE_MODE" ]; then
    # Quick template mode
    echo "Using template: $TEMPLATE_MODE"
    PROJECT_NAME=$(gum input --header "Project name:")
    [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
    
    setup_template "$TEMPLATE_MODE"
    
else
    # Interactive mode
    CHOICE=$(gum choose "Use Template" "Custom Setup" --header "Quick start or custom?")
    
    if [ "$CHOICE" = "Use Template" ]; then
        TEMPLATE=$(gum choose "basic-dst" "basic-ndr" "basic-personal" "r-analysis" "geospatial" --header "Select template:")
        [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
        
        PROJECT_NAME=$(gum input --header "Project name:")
        [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
        
        setup_template "$TEMPLATE"
        
    else
        # Full custom setup
        BASE_DIR=$(gum input --header "Base directory" --value "$HOME/projects")
        [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
        
        BASE_DIR="${BASE_DIR/#\~/$HOME}"
        [ ! -d "$BASE_DIR" ] && mkdir -p "$BASE_DIR"
        BASE_DIR=$(realpath "$BASE_DIR")
        
        CATEGORY=$(gum choose "Personal" "NDR" "DST" "Custom" --header "Category:")
        [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
        
        if [ "$CATEGORY" = "Custom" ]; then
            PROJECT_NAME=$(gum input --header "Project name:")
            [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
            
            PARENT_DIR=$(gum input --header "Parent directory:" --value "$HOME")
            [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
            
            PARENT_DIR="${PARENT_DIR/#\~/$HOME}"
            [ ! -d "$PARENT_DIR" ] && mkdir -p "$PARENT_DIR"
            
            PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g')
            TARGET_DIR="$PARENT_DIR/$PROJECT_SLUG"
        else
            YEAR=$(gum input --header "Year:" --value "$(date +%Y)")
            [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
            
            MONTH=$(gum input --header "Month:" --value "$(date +%m)")
            [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
            MONTH=$(printf "%02d" "${MONTH#0}")
            
            PROJECT_NAME=$(gum input --header "Project name:")
            [ $? -ne 0 ] && { echo "Cancelled"; return 1; }
            
            PROJECT_SLUG=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g')
            TARGET_DIR="$BASE_DIR/$YEAR/$MONTH/$YEAR-$MONTH-$PROJECT_SLUG"
        fi
        
        # Ask about components for custom setup
        ADD_R=false
        ADD_QGIS=false
        gum confirm "Add R components?" && ADD_R=true
        gum confirm "Add QGIS components?" && ADD_QGIS=true
    fi
fi

# Create project directory
if [ -e "$TARGET_DIR" ]; then
    gum confirm "Path exists. Continue?" || { echo "Cancelled"; return 0; }
fi

mkdir -p "$TARGET_DIR" || { echo "Failed to create directory"; return 1; }
PROJECT_ROOT_DIR=$(realpath "$TARGET_DIR")
PROJECT_ROOT_DIR_TO_CLEANUP="$PROJECT_ROOT_DIR"

cd "$PROJECT_ROOT_DIR" || { echo "Failed to cd"; return 1; }

# Ask for project manager integration
if gum confirm "Add project to DAV Project Manager?"; then
    # Source the project manager script
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
    PROJECT_MANAGER_SCRIPT="$SCRIPT_DIR/dav_project_manager.sh"
    
    if [ -f "$PROJECT_MANAGER_SCRIPT" ]; then
        source "$PROJECT_MANAGER_SCRIPT"
        
        # Determine project type based on components
        PROJECT_TYPE="mixed"
        if [ "$ADD_R" = true ] && [ "$ADD_QGIS" = true ]; then
            PROJECT_TYPE="geospatial"
        elif [ "$ADD_R" = true ]; then
            PROJECT_TYPE="r-analysis"
        elif [ "$ADD_QGIS" = true ]; then
            PROJECT_TYPE="qgis"
        fi
        
        # Add project to manager
        add_project "$PROJECT_NAME" "$PROJECT_ROOT_DIR" "$PROJECT_TYPE"
        echo "Project added to DAV Project Manager!"
    else
        echo "Project manager script not found: $PROJECT_MANAGER_SCRIPT"
    fi
fi

# Ask for traditional alias as backup
if gum confirm "Add traditional shell alias for this project?"; then
    ALIAS_FILE="$HOME/.zshrc-aliases"
    [ ! -f "$ALIAS_FILE" ] && ALIAS_FILE="$HOME/.zshrc"
    [ ! -f "$ALIAS_FILE" ] && ALIAS_FILE="$HOME/.bashrc"
    
    if [ -f "$ALIAS_FILE" ]; then
        FUNC_NAME=$(gum input --header "Function name:" --value "p_$PROJECT_SLUG")
        if [ -n "$FUNC_NAME" ]; then
            echo "" >> "$ALIAS_FILE"
            echo "# Project: $PROJECT_NAME" >> "$ALIAS_FILE"
            echo "function $FUNC_NAME() { cd '$PROJECT_ROOT_DIR'; }" >> "$ALIAS_FILE"
            echo "Added function $FUNC_NAME to $ALIAS_FILE"
        fi
    fi
fi

# Setup Git
[ ! -d ".git" ] && { git init -q; echo ".Rhistory" > .gitignore; echo "*~" >> .gitignore; }

# Create directory structure
mkdir -p data/{csv,excel,misc} data/geodata/{raster,vector} graphic_output docs scripts

# Setup R components
if [ "$ADD_R" = true ]; then
    mkdir -p R
    cat > "$PROJECT_SLUG.Rproj" << EOF
Version: 1.0
RestoreWorkspace: Default
SaveWorkspace: Default
AlwaysSaveHistory: Default
EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8
VersionControl: Git
EOF
    
    # Create init.R file
    cat > "R/init.R" << EOF
# Load required packages
library(here)
library(tidyverse)
library(sf)
library(glue)
library(httr)
library(cli)
library(davR)
library(terra)


# Set up project paths
p_data = here("data")
p_csv = here("data", "csv")
p_excel = here("data", "excel")
p_geo_vec = here("data", "geodata", "vector")
p_geo_ras = here("data", "geodata", "raster")
p_graphic = here("graphic_output")

EOF
fi

# Setup QGIS components  
if [ "$ADD_QGIS" = true ]; then
    mkdir -p qgis/{scripts,models,styles}
    cat > "$PROJECT_SLUG.qgs" << EOF
<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis version="3.34.0" projectname="$PROJECT_SLUG">
  <homePath path="."/>
  <title>$PROJECT_NAME</title>
  <autotransaction active="0"/>
  <evaluateDefaultValues active="0"/>
  <trust active="0"/>
  <projectCrs>
    <spatialrefsys>
      <wkt>GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Latitude",NORTH],AXIS["Longitude",EAST],AUTHORITY["EPSG","4326"]]</wkt>
      <proj4>+proj=longlat +datum=WGS84 +no_defs</proj4>
      <srsid>3452</srsid>
      <srid>4326</srid>
      <authid>EPSG:4326</authid>
      <description>WGS 84</description>
      <projectionacronym>longlat</projectionacronym>
      <ellipsoidacronym>WGS84</ellipsoidacronym>
      <geographicflag>true</geographicflag>
    </spatialrefsys>
  </projectCrs>
  <layer-tree-group>
    <layer-tree-layer id="OpenStreetMap_0" name="OpenStreetMap" providerKey="wms" source="type=xyz&amp;url=https://tile.openstreetmap.org/{z}/{x}/{y}.png&amp;zmax=19&amp;zmin=0" checked="Qt::Checked" expanded="1"/>
  </layer-tree-group>
  <maplayers>
    <maplayer type="raster" id="OpenStreetMap_0" hasScaleBasedVisibilityFlag="0">
      <pipe>
        <provider>
          <resampling maxOversampling="2" enabled="false" algorithm="0"/>
        </provider>
      </pipe>
      <customproperties/>
      <blendMode>0</blendMode>
    </maplayer>
  </maplayers>
</qgis>
EOF
fi

# Create README
cat > README.md << EOF
# $PROJECT_NAME

Created: $(date +"%Y-%m-%d")
Location: $PROJECT_ROOT_DIR

## Structure
- data/: Input and output data
  - csv/
  - excel/
  - geodata/
    - vector/
    - raster/
- graphic_output/: Charts and maps
- docs/: Documentation and Quarto files
- scripts/: General scripts
EOF

[ "$ADD_R" = true ] && echo "- R/: R scripts" >> README.md
[ "$ADD_QGIS" = true ] && echo "- qgis/: QGIS files" >> README.md

# Create Quarto Doc
cat > "docs/$PROJECT_SLUG.qmd" << EOF
---
title: "$PROJECT_NAME"
format:
  html:
    theme: cosmo
    toc: true
    toc-depth: 3
    toc-location: left
    code-fold: true
    code-summary: "Show Code"
    backgroundcolor: "#C6DC73"
    grid:
      body-width: 600px
editor: source
execute:
  echo: true
  warning: false
  message: false
  freeze: auto
---

\`\`\`{r setup, include=FALSE}
knitr::opts_chunk\$set(echo = TRUE, warning = FALSE, message = FALSE)
library(tidyverse)
library(polyglotr)
library(here)
library(glue)
library(sf)
library(davR)
library(jsonlite)
library(mapview)
library(DatawRappr)
library(DT)
library(gt)
library(zoo)

m <- mapview

# Define paths
p_data = here("data")
p_csv = here("data", "csv")
p_excel = here("data", "excel")
p_geo_vec = here("data", "geodata", "vector")
p_geo_ras = here("data", "geodata", "raster")
p_graphic = here("graphic_output")
\`\`\`

EOF

echo ""
echo "Project created: $PROJECT_ROOT_DIR"
ls -la

# Offer global createdp alias
if [ -n "$ZSH_VERSION" ]; then
    SCRIPT_PATH=$(realpath "${(%):-%x}")
else
    SCRIPT_PATH=$(realpath "${BASH_SOURCE[0]}")
fi

GLOBAL_ALIAS_FILE="$HOME/.zshrc-aliases"
[ ! -f "$GLOBAL_ALIAS_FILE" ] && GLOBAL_ALIAS_FILE="$HOME/.zshrc"

if [ -f "$GLOBAL_ALIAS_FILE" ]; then
    ALIAS_EXISTS=$(grep -c "alias createdp=" "$GLOBAL_ALIAS_FILE")
    
    if [ "$ALIAS_EXISTS" -gt 0 ]; then
        # Alias exists, check if the path is correct
        EXISTING_PATH=$(grep "alias createdp=" "$GLOBAL_ALIAS_FILE" | sed -n 's/.*source "\(.*\)".*/\1/p' | head -1)
        if [ "$EXISTING_PATH" != "$SCRIPT_PATH" ]; then
            sed -i.bak "s|alias createdp='source \".*\"'|alias createdp='source \"$SCRIPT_PATH\"'|g" "$GLOBAL_ALIAS_FILE"
            echo "Updated 'createdp' alias in $GLOBAL_ALIAS_FILE to point to new location."
        fi
    else
        # Alias does not exist, create it
        echo "" >> "$GLOBAL_ALIAS_FILE"
        echo "alias createdp='source \"$SCRIPT_PATH\"'" >> "$GLOBAL_ALIAS_FILE"
        echo "Added global 'createdp' alias to $GLOBAL_ALIAS_FILE. Run 'source $GLOBAL_ALIAS_FILE' to use it."
    fi
fi

# Git commit at the end
if gum confirm "Make initial commit?"; then
    git add .
    git commit -m "Initial structure for $PROJECT_NAME"
fi

# Open applications at the end (interactive selection)
echo ""
if command -v gum >/dev/null 2>&1; then
    AVAILABLE_APPS=()
    APP_LABELS=()
    # Always offer editor and terminal
    AVAILABLE_APPS+=("cursor")
    APP_LABELS+=("📝 Cursor/VS Code")
    AVAILABLE_APPS+=("terminal")
    APP_LABELS+=("💻 Terminal (cd to project)")
    # Conditionally offer RStudio/QGIS
    if [ "$ADD_R" = true ]; then
        AVAILABLE_APPS+=("rstudio")
        APP_LABELS+=("📊 RStudio (.Rproj)")
    fi
    if [ "$ADD_QGIS" = true ]; then
        AVAILABLE_APPS+=("qgis")
        APP_LABELS+=("🗺️  QGIS (.qgs)")
    fi

    echo "Which apps do you want to open now?"
    # gum choose prints the selected values, one per line
    SELECTED=$(printf '%s\n' "${AVAILABLE_APPS[@]}" | gum choose --no-limit --header "Open applications:" --height 8)
    if [ -n "$SELECTED" ]; then
        while IFS= read -r app; do
            case "$app" in
                "cursor")
                    if command -v cursor >/dev/null 2>&1; then
                        cursor . 2>/dev/null &
                    elif command -v code >/dev/null 2>&1; then
                        code . 2>/dev/null &
                    else
                        echo "Editor not found (cursor/code)."
                    fi
                    ;;
                "terminal")
                    # Prefer iTerm2 if available, fallback to Terminal (macOS)
                    if command -v osascript >/dev/null 2>&1; then
                        # Check for iTerm by trying to get its version silently
                        if osascript -e 'tell application id "com.googlecode.iterm2" to version' >/dev/null 2>&1; then
                            osascript >/dev/null 2>&1 <<OSA
tell application id "com.googlecode.iterm2"
    if (exists current window) then
        tell current window
            create tab with default profile
            tell current session
                write text "cd '$PROJECT_ROOT_DIR'"
            end tell
        end tell
    else
        create window with default profile
        tell current session of current window
            write text "cd '$PROJECT_ROOT_DIR'"
        end tell
    end if
    activate
end tell
OSA
                        else
                            osascript >/dev/null 2>&1 <<OSA
tell application "Terminal"
    do script "cd '$PROJECT_ROOT_DIR'"
    activate
end tell
OSA
                        fi
                    fi
                    ;;
                "rstudio")
                    if [ -f "$PROJECT_SLUG.Rproj" ] && command -v open >/dev/null 2>&1; then
                        open "$PROJECT_SLUG.Rproj" 2>/dev/null &
                    else
                        echo "Cannot open RStudio project file."
                    fi
                    ;;
                "qgis")
                    if [ -f "$PROJECT_SLUG.qgs" ]; then
                        if command -v qgis >/dev/null 2>&1; then
                            qgis "$PROJECT_SLUG.qgs" &
                        elif command -v open >/dev/null 2>&1; then
                            # Try with explicit app name first, then fallback to default
                            (open -a QGIS "$PROJECT_SLUG.qgs" 2>/dev/null || open -a QGIS-LTR "$PROJECT_SLUG.qgs" 2>/dev/null || open "$PROJECT_SLUG.qgs") &
                        else
                            echo "Cannot open QGIS project file. Neither 'qgis' nor 'open' command is available."
                        fi
                    else
                        echo "QGIS project file '$PROJECT_SLUG.qgs' not found."
                    fi
                    ;;
            esac
        done <<EOF
$SELECTED
EOF
    fi
else
    # Fallback: open nothing automatically, but show clear instructions
    echo "You can now open any of these from the project folder:"
    echo "- Cursor: cursor ."
    echo "- VS Code: code ."
    [ "$ADD_R" = true ] && echo "- RStudio: open '$PROJECT_SLUG.Rproj'"
    [ "$ADD_QGIS" = true ] && echo "- QGIS: open '$PROJECT_SLUG.qgs'"
fi

# Graceful success message
echo ""
echo "✅ Project created successfully!"
echo "📂 Location: $PROJECT_ROOT_DIR"
echo "📝 README: $PROJECT_ROOT_DIR/README.md"

SCRIPT_SUCCESSFUL=true
exit 0