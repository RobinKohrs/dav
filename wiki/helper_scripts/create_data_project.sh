#!/usr/bin/env bash

# --- Configuration ---
DEFAULT_BASE_PROJECT_DIR="$HOME/projects"
FIND_MAX_DEPTH=5
FZF_HEIGHT="70%"

# --- Helper Functions ---
check_dependency() {
  command -v "$1" >/dev/null 2>&1 || {
    gum style --foreground="red" "Error: Dependency '$1' not found." \
              "Please install it to use this script." \
              "(e.g., check $(gum style --underline "$2"))"
    exit 1
  }
}

print_success() {
  gum style --border="double" --border-foreground="green" --padding="1 2" \
            "Success!" "$1" "Project root: $(gum style --bold "$2")"
}

print_error() {
  gum style --foreground="red" "Error: $1"
  exit 1
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


# --- Main Script ---

# 1. Determine Base Project Directory
BASE_PROJECT_DIR_INPUT=$(gum input --header "Enter the base directory for ALL your projects" --placeholder "e.g., ~/projects, ~/work, etc." --value "$DEFAULT_BASE_PROJECT_DIR")
if [ -z "$BASE_PROJECT_DIR_INPUT" ]; then
    print_error "Base project directory cannot be empty. Aborting."
fi

# Resolve BASE_PROJECT_DIR_INPUT to an absolute path string
TEMP_BASE_PATH="${BASE_PROJECT_DIR_INPUT/#\~/$HOME}" # Expand tilde
if [[ "$TEMP_BASE_PATH" != /* ]]; then # If not absolute, make it absolute
  TEMP_BASE_PATH="$(pwd)/$TEMP_BASE_PATH"
fi
# TEMP_BASE_PATH is now an absolute path string, but might not be canonical or exist yet.

BASE_PROJECT_DIR_CONFIG="" # This will hold the final canonical path

if [ ! -d "$TEMP_BASE_PATH" ]; then
    gum confirm "Base directory '$TEMP_BASE_PATH' does not exist. Create it?" --default=true || {
        print_error "Base directory '$TEMP_BASE_PATH' not found and not created. Aborting."
    }
    mkdir -p "$TEMP_BASE_PATH" || print_error "Failed to create base directory '$TEMP_BASE_PATH'. Check permissions."
    BASE_PROJECT_DIR_CONFIG=$(realpath "$TEMP_BASE_PATH") # Canonicalize after creation
    gum format -- "- Created base project directory: **$BASE_PROJECT_DIR_CONFIG**"
else
    # Path exists, ensure it's a directory and canonicalize
    if [ ! -d "$TEMP_BASE_PATH" ]; then
        print_error "Path '$TEMP_BASE_PATH' exists but is not a directory. Aborting."
    fi
    BASE_PROJECT_DIR_CONFIG=$(realpath "$TEMP_BASE_PATH") # Canonicalize existing path
    gum format -- "- Using base project directory: **$BASE_PROJECT_DIR_CONFIG**"
fi


# 2. Determine Project Category and then Project Root & Name
PROJECT_CATEGORY=$(gum choose "Personal" "NDR" "DST" "Custom (free parent/name selection)" --header "Select project category:" --height 5)

if [ -z "$PROJECT_CATEGORY" ]; then
  print_error "No project category selected. Aborting."
fi

PROJECT_ROOT_DIR="" # This will be the final canonical project root
PROJECT_NAME=""     # This will be the sanitized core name for files etc.

if [[ "$PROJECT_CATEGORY" == "Personal" || "$PROJECT_CATEGORY" == "NDR" || "$PROJECT_CATEGORY" == "DST" ]]; then
  gum format -- "- Selected category: **$PROJECT_CATEGORY**"
  CURRENT_YEAR=$(date +%Y)
  PROJECT_YEAR=$(gum input --placeholder "Enter year (YYYY)" --value "$CURRENT_YEAR" --header "Project Year:")
  if ! [[ "$PROJECT_YEAR" =~ ^[0-9]{4}$ ]]; then
    print_error "Invalid year format. Please use YYYY. Aborting."
  fi

  CURRENT_MONTH=$(date +%m)
  PROJECT_MONTH_INPUT=$(gum input --placeholder "Enter month (MM, e.g., 07)" --value "$CURRENT_MONTH" --header "Project Month:")
  if ! [[ "$PROJECT_MONTH_INPUT" =~ ^(0?[1-9]|1[0-2])$ ]]; then
      print_error "Invalid month format. Please use MM (01-12). Aborting."
  fi
  PROJECT_MONTH=$(printf "%02d" "${PROJECT_MONTH_INPUT#0}")

  CORE_PROJECT_NAME_INPUT=$(gum input --placeholder "Enter a short name for your project (e.g., 'tree_analysis')" --header "Core Project Name:")
  if [ -z "$CORE_PROJECT_NAME_INPUT" ]; then
    print_error "Core project name cannot be empty. Aborting."
  fi
  PROJECT_NAME=$(echo "$CORE_PROJECT_NAME_INPUT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g' | sed 's:/*$::')
  if [ -z "$PROJECT_NAME" ]; then
      print_error "Sanitized project name is empty. Please use more alphanumeric characters."
  fi
  gum format -- "- Core project name (for files & dir part) set to: **$PROJECT_NAME**"

  PROJECT_CATEGORY_LOWER=$(echo "$PROJECT_CATEGORY" | tr '[:upper:]' '[:lower:]')
  PROJECT_DIR_LEAF_NAME="$PROJECT_YEAR-$PROJECT_MONTH-$PROJECT_NAME"

  TARGET_PROJECT_ROOT_DIR="$BASE_PROJECT_DIR_CONFIG/$PROJECT_CATEGORY_LOWER/$PROJECT_DIR_LEAF_NAME"

  gum format -- "- Target project root will be: **$TARGET_PROJECT_ROOT_DIR**"
  if [ -e "$TARGET_PROJECT_ROOT_DIR" ]; then
    gum confirm "Path '$TARGET_PROJECT_ROOT_DIR' already exists. Continue and potentially add/overwrite files?" --default=false || {
      echo "Operation cancelled by user."
      exit 0
    }
    echo "Proceeding with existing path..."
    if [ ! -d "$TARGET_PROJECT_ROOT_DIR" ]; then
        print_error "Path '$TARGET_PROJECT_ROOT_DIR' exists but is not a directory. Aborting."
    fi
    PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR") # Canonicalize existing
  else
    mkdir -p "$TARGET_PROJECT_ROOT_DIR" || print_error "Failed to create directory '$TARGET_PROJECT_ROOT_DIR'. Check permissions."
    PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR") # Canonicalize newly created
  fi

elif [[ "$PROJECT_CATEGORY" == "Custom (free parent/name selection)" ]]; then
  gum format -- "- Selected category: **Custom**"
  CORE_PROJECT_NAME_INPUT=$(gum input --placeholder "Enter a name for your new project folder (e.g., 'ad_hoc_report')" --header "Project Folder Name:")
  if [ -z "$CORE_PROJECT_NAME_INPUT" ]; then
    print_error "Project folder name cannot be empty for a custom project."
  fi
  PROJECT_NAME=$(echo "$CORE_PROJECT_NAME_INPUT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_-]//g' | sed 's:/*$::')
  if [ -z "$PROJECT_NAME" ]; then
      print_error "Sanitized project name is empty. Please use more alphanumeric characters."
  fi
  gum format -- "- Project name (for files and folder) set to: **$PROJECT_NAME**"

  # BASE_PROJECT_DIR_CONFIG is already canonical and existing at this point
  gum format -- "- Select PARENT directory for the new '$PROJECT_NAME' folder (searching under '$BASE_PROJECT_DIR_CONFIG')..."
  gum spin --spinner="line" --title="Searching for parent directories (max depth $FIND_MAX_DEPTH from $BASE_PROJECT_DIR_CONFIG)..." -- sleep infinity &
  SPIN_PID=$!
  trap 'kill $SPIN_PID >/dev/null 2>&1; wait $SPIN_PID 2>/dev/null' EXIT SIGINT SIGTERM

  FZF_HEADER_CUSTOM="Select PARENT directory (under $BASE_PROJECT_DIR_CONFIG) for the new '$PROJECT_NAME' folder"
  PARENT_DIR_FOR_CUSTOM_SELECTED=$(find "$BASE_PROJECT_DIR_CONFIG" -mindepth 1 -maxdepth "$FIND_MAX_DEPTH" -type d \
    \( -name ".git" -o -name "node_modules" -o -name ".cache" -o -name "venv" -o -name ".venv" -o -path "*/.*" \) -prune \
    -o -print 2>/dev/null | fzf --header="$FZF_HEADER_CUSTOM" \
                                 --height="$FZF_HEIGHT" --border \
                                 --preview='ls -lah --color=always {} | head -n 20' --exit-0 --select-1 --no-multi)
  FZF_EXIT_CODE=$?
  kill $SPIN_PID >/dev/null 2>&1; wait $SPIN_PID 2>/dev/null; trap - EXIT SIGINT SIGTERM

  if [ $FZF_EXIT_CODE -ne 0 ] || [ -z "$PARENT_DIR_FOR_CUSTOM_SELECTED" ]; then
      print_error "No parent directory selected for custom project. Aborting."
  fi
  if [ ! -d "$PARENT_DIR_FOR_CUSTOM_SELECTED" ]; then # Should be redundant given fzf selects existing dir
    print_error "The selected path '$PARENT_DIR_FOR_CUSTOM_SELECTED' is not a valid directory."
  fi
  PARENT_DIR_FOR_CUSTOM=$(realpath "$PARENT_DIR_FOR_CUSTOM_SELECTED") # Canonicalize (safe, path exists)

  TARGET_PROJECT_ROOT_DIR="$PARENT_DIR_FOR_CUSTOM/$PROJECT_NAME"

  gum format -- "- Target project root will be: **$TARGET_PROJECT_ROOT_DIR**"
  if [ -e "$TARGET_PROJECT_ROOT_DIR" ]; then
    gum confirm "Directory '$TARGET_PROJECT_ROOT_DIR' already exists. Continue and potentially add/overwrite files?" --default=false || {
      echo "Operation cancelled by user."
      exit 0
    }
    echo "Proceeding with existing directory..."
    if [ ! -d "$TARGET_PROJECT_ROOT_DIR" ]; then
        print_error "Path '$TARGET_PROJECT_ROOT_DIR' exists but is not a directory. Aborting."
    fi
    PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR") # Canonicalize existing
  else
    mkdir -p "$TARGET_PROJECT_ROOT_DIR" || print_error "Failed to create directory '$TARGET_PROJECT_ROOT_DIR'. Check permissions."
    PROJECT_ROOT_DIR=$(realpath "$TARGET_PROJECT_ROOT_DIR") # Canonicalize newly created
  fi
else
    print_error "Invalid project category selected. This should not happen. Aborting."
fi

# --- Change to Project Root and Setup ---
cd "$PROJECT_ROOT_DIR" || print_error "Failed to change directory to $PROJECT_ROOT_DIR"
gum format -- "- Changed directory to: **$(pwd)**"

# 2. Initialize Git Repository (if not already one)
if [ ! -d ".git" ]; then
    gum spin --spinner="dot" --title="Initializing Git repository in $PROJECT_ROOT_DIR..." -- \
    git init -q || print_error "Failed to initialize Git repository."
    gum format -- "- Initialized Git repository."
else
    gum format -- "- Git repository already exists."
fi

# 3. Create comprehensive .gitignore
gum format -- "- Creating/Updating .gitignore in **$PROJECT_ROOT_DIR/.gitignore**..."
cat << EOF > ".gitignore"
# --- General ---
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
*~

# --- R (Project file .Rproj is at root, R code/data in R/ subdir) ---
.Rhistory        # If R is run from project root
.Rapp.history    # If R is run from project root
.RData           # If R is run from project root, SAVE THIS?
.Ruserdata
.Rproj.user/     # User-specific RStudio files for the .Rproj at root
R/.Rhistory      # If R is run from R/ sub-directory
R/.RData         # If R is run from R/ sub-directory, SAVE THIS?
R/*_cache/
R/cache/
.Renviron        # Project-specific R environment variables at root
.httr-oauth      # OAuth tokens, typically at root or where script runs
rsconnect/       # RStudio Connect deployment files, typically at root

# --- QGIS (Project file .qgs/.qgz is at root, QGIS data in qgis/ subdir) ---
# QGIS backup files for the project file at root
*.qgs~
*.qgz~
# QGIS backup files if a project file were inside qgis/ (less likely with new structure)
# qgis/*.qgs~
# qgis/*.qgz~

# --- Python ---
.venv/
venv/
*.pyc
__pycache__/
.env
.python-version
.mypy_cache/
.pytest_cache/
.ruff_cache/

# --- Data (adjust paths as needed) ---
# Example: if you want to ignore all data in subfolders by default.
# Consider if data should be tracked or use Git LFS.
# R/data_raw/
# R/data_output/
# qgis/data_raw/
# qgis/data_output/
# data/
# output/

# --- Large Files (Consider Git LFS: https://git-lfs.github.com/) ---
# *.tif
# *.gpkg
# *.shp
# *.parquet
# *.feather
# *.rds # Often large, consider for LFS if in R/data_output/
# *.pdf
# *.pptx
# *.docx
# *.zip
# *.tar.gz

# --- Secrets (NEVER commit credentials!) ---
*.cred
*.secret
credentials.*
secret.*
*key*
*token*
*.pem
*.key

# --- OS Specific ---
desktop.ini

# --- IDEs ---
.vscode/
.idea/
*.swp
*.swo
nbproject/ # NetBeans
*.sublime-project
*.sublime-workspace

# --- Node.js ---
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
package-lock.json # Often committed, but can be ignored in some workflows
yarn.lock         # Often committed

# --- Compiled output ---
build/
dist/
out/
target/

# --- Log files ---
*.log
logs/
EOF

# --- Optional Components ---

# 4. Ask about R components
ADD_R=false
RPROJ_FILE_ABS="$PROJECT_ROOT_DIR/$PROJECT_NAME.Rproj"
R_SUBDIRS_PATH="$PROJECT_ROOT_DIR/R"

if gum confirm "Add R project components? ($PROJECT_NAME.Rproj in root, subdirs in R/)?"; then
  ADD_R=true
  gum spin --spinner="dot" --title="Setting up R components..." -- sleep 0.5

  mkdir -p "$R_SUBDIRS_PATH/analysis"
  mkdir -p "$R_SUBDIRS_PATH/data_raw"
  mkdir -p "$R_SUBDIRS_PATH/data_output"
  mkdir -p "$R_SUBDIRS_PATH/functions"
  mkdir -p "$R_SUBDIRS_PATH/doc"


  echo "Creating R project file: $RPROJ_FILE_ABS"
  cat << EOF_RPROJ > "$RPROJ_FILE_ABS"
Version: 1.0
ProjectName: $PROJECT_NAME
RestoreWorkspace: Default
SaveWorkspace: Default
AlwaysSaveHistory: Default
EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8
RnwWeave: Sweave
LaTeX: pdfLaTeX

# Project Root is: $PROJECT_ROOT_DIR
# R code/data subdirectories in: R/ (relative to this .Rproj file)
# Analysis scripts/docs likely in: R/analysis/
# Custom functions in: R/functions/
# Raw data in: R/data_raw/, Processed data in: R/data_output/
# Use here::here() for robust paths relative to the project root ($PROJECT_ROOT_DIR)
EOF_RPROJ
  gum format -- "- Added R project file: **$RPROJ_FILE_ABS**"
  gum format -- "- Added R subdirectories in: **$R_SUBDIRS_PATH/**"
fi

# 5. Ask about QGIS components
ADD_QGIS=false
QGIS_PROJ_FILE_ABS="$PROJECT_ROOT_DIR/$PROJECT_NAME.qgs"
QGIS_SUBDIRS_PATH="$PROJECT_ROOT_DIR/qgis"
QGIS_SAVE_USER="${USER:-unknown_user}" # Get current username
QGIS_SAVE_DATETIME=$(date +"%Y-%m-%dT%H:%M:%S") # Format: 2024-07-16T10:30:00
QGIS_CREATION_DATE=$(date +"%Y-%m-%d") # Format: 2024-07-16

if gum confirm "Add QGIS project components? ($PROJECT_NAME.qgs in root, subdirs in qgis/)?"; then
  ADD_QGIS=true
  gum spin --spinner="line" --title="Setting up QGIS components..." -- sleep 0.5

  mkdir -p "$QGIS_SUBDIRS_PATH/data_raw/vector/polygon"
  mkdir -p "$QGIS_SUBDIRS_PATH/data_raw/vector/line"
  mkdir -p "$QGIS_SUBDIRS_PATH/data_raw/vector/point"
  mkdir -p "$QGIS_SUBDIRS_PATH/data_raw/raster"
  mkdir -p "$QGIS_SUBDIRS_PATH/data_raw/tabular"
  mkdir -p "$QGIS_SUBDIRS_PATH/data_output"
  mkdir -p "$QGIS_SUBDIRS_PATH/graphic_output"
  mkdir -p "$QGIS_SUBDIRS_PATH/scripts"
  mkdir -p "$QGIS_SUBDIRS_PATH/models"
  mkdir -p "$QGIS_SUBDIRS_PATH/styles"

  gum format -- "- Added QGIS subdirectories in **$QGIS_SUBDIRS_PATH/**"

  echo "Creating QGIS project file: $QGIS_PROJ_FILE_ABS"
  # Using the user-provided template structure, with dynamic projectname, user, and dates
  cat << EOF_QGIS > "$QGIS_PROJ_FILE_ABS"
<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis saveUser="$QGIS_SAVE_USER" saveDateTime="$QGIS_SAVE_DATETIME" version="3.40.3-Bratislava" projectname="$PROJECT_NAME" saveUserFull="$QGIS_SAVE_USER">
  <homePath path=""/>
  <title></title>
  <transaction mode="Disabled"/>
  <projectFlags set=""/>
  <projectCrs>
    <spatialrefsys nativeFormat="Wkt">
      <wkt>GEOGCRS["WGS 84",ENSEMBLE["World Geodetic System 1984 ensemble",MEMBER["World Geodetic System 1984 (Transit)"],MEMBER["World Geodetic System 1984 (G730)"],MEMBER["World Geodetic System 1984 (G873)"],MEMBER["World Geodetic System 1984 (G1150)"],MEMBER["World Geodetic System 1984 (G1674)"],MEMBER["World Geodetic System 1984 (G1762)"],ELLIPSOID["WGS 84",6378137,298.257223563,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[2.0]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["geodetic latitude (Lat)",north,ORDER[1],ANGLEUNIT["degree",0.0174532925199433]],AXIS["geodetic longitude (Lon)",east,ORDER[2],ANGLEUNIT["degree",0.0174532925199433]],USAGE[SCOPE["Horizontal component of 3D system."],AREA["World."],BBOX[-90,-180,90,180]],ID["EPSG",4326]]</wkt>
      <proj4>+proj=longlat +datum=WGS84 +no_defs</proj4>
      <srsid>3452</srsid>
      <srid>4326</srid>
      <authid>EPSG:4326</authid>
      <description>WGS 84</description>
      <projectionacronym>longlat</projectionacronym>
      <ellipsoidacronym>EPSG:7030</ellipsoidacronym>
      <geographicflag>true</geographicflag>
    </spatialrefsys>
  </projectCrs>
  <verticalCrs>
    <spatialrefsys nativeFormat="Wkt">
      <wkt></wkt>
      <proj4></proj4>
      <srsid>0</srsid>
      <srid>0</srid>
      <authid></authid>
      <description></description>
      <projectionacronym></projectionacronym>
      <ellipsoidacronym></ellipsoidacronym>
      <geographicflag>false</geographicflag>
    </spatialrefsys>
  </verticalCrs>
  <elevation-shading-renderer edl-distance-unit="0" hillshading-z-factor="1" light-azimuth="315" is-active="0" combined-method="0" edl-distance="0.5" hillshading-is-multidirectional="0" edl-is-active="1" light-altitude="45" edl-strength="1000" hillshading-is-active="0"/>
  <layer-tree-group>
    <customproperties>
      <Option/>
    </customproperties>
    <custom-order enabled="0"/>
  </layer-tree-group>
  <snapping-settings enabled="0" mode="2" self-snapping="0" type="1" tolerance="12" intersection-snapping="0" scaleDependencyMode="0" unit="1" maxScale="0" minScale="0">
    <individual-layer-settings/>
  </snapping-settings>
  <relations/>
  <polymorphicRelations/>
  <mapcanvas name="theMapCanvas" annotationsVisible="1">
    <units>degrees</units>
    <extent>
      <xmin>-1</xmin>
      <ymin>-1</ymin>
      <xmax>1</xmax>
      <ymax>1</ymax>
    </extent>
    <rotation>0</rotation>
    <destinationsrs>
      <spatialrefsys nativeFormat="Wkt">
        <wkt>GEOGCRS["WGS 84",ENSEMBLE["World Geodetic System 1984 ensemble",MEMBER["World Geodetic System 1984 (Transit)"],MEMBER["World Geodetic System 1984 (G730)"],MEMBER["World Geodetic System 1984 (G873)"],MEMBER["World Geodetic System 1984 (G1150)"],MEMBER["World Geodetic System 1984 (G1674)"],MEMBER["World Geodetic System 1984 (G1762)"],ELLIPSOID["WGS 84",6378137,298.257223563,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[2.0]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["geodetic latitude (Lat)",north,ORDER[1],ANGLEUNIT["degree",0.0174532925199433]],AXIS["geodetic longitude (Lon)",east,ORDER[2],ANGLEUNIT["degree",0.0174532925199433]],USAGE[SCOPE["Horizontal component of 3D system."],AREA["World."],BBOX[-90,-180,90,180]],ID["EPSG",4326]]</wkt>
        <proj4>+proj=longlat +datum=WGS84 +no_defs</proj4>
        <srsid>3452</srsid>
        <srid>4326</srid>
        <authid>EPSG:4326</authid>
        <description>WGS 84</description>
        <projectionacronym>longlat</projectionacronym>
        <ellipsoidacronym>EPSG:7030</ellipsoidacronym>
        <geographicflag>true</geographicflag>
      </spatialrefsys>
    </destinationsrs>
    <rendermaptile>0</rendermaptile>
    <expressionContextScope/>
  </mapcanvas>
  <projectModels/>
  <legend updateDrawingOrder="true"/>
  <mapViewDocks/>
  <main-annotation-layer type="annotation" autoRefreshTime="0" autoRefreshMode="Disabled" refreshOnNotifyEnabled="0" styleCategories="AllStyleCategories" refreshOnNotifyMessage="" legendPlaceholderImage="" hasScaleBasedVisibilityFlag="0" maxScale="0" minScale="1e+08">
    <id>Annotations_$(uuidgen || date +%s%N)</id> <!-- Dynamic ID -->
    <datasource></datasource>
    <keywordList>
      <value></value>
    </keywordList>
    <layername>Annotations</layername>
    <srs>
      <spatialrefsys nativeFormat="Wkt">
        <wkt>GEOGCRS["WGS 84",ENSEMBLE["World Geodetic System 1984 ensemble",MEMBER["World Geodetic System 1984 (Transit)"],MEMBER["World Geodetic System 1984 (G730)"],MEMBER["World Geodetic System 1984 (G873)"],MEMBER["World Geodetic System 1984 (G1150)"],MEMBER["World Geodetic System 1984 (G1674)"],MEMBER["World Geodetic System 1984 (G1762)"],ELLIPSOID["WGS 84",6378137,298.257223563,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[2.0]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["geodetic latitude (Lat)",north,ORDER[1],ANGLEUNIT["degree",0.0174532925199433]],AXIS["geodetic longitude (Lon)",east,ORDER[2],ANGLEUNIT["degree",0.0174532925199433]],USAGE[SCOPE["Horizontal component of 3D system."],AREA["World."],BBOX[-90,-180,90,180]],ID["EPSG",4326]]</wkt>
        <proj4>+proj=longlat +datum=WGS84 +no_defs</proj4>
        <srsid>3452</srsid>
        <srid>4326</srid>
        <authid>EPSG:4326</authid>
        <description>WGS 84</description>
        <projectionacronym>longlat</projectionacronym>
        <ellipsoidacronym>EPSG:7030</ellipsoidacronym>
        <geographicflag>true</geographicflag>
      </spatialrefsys>
    </srs>
    <resourceMetadata>
      <identifier></identifier>
      <parentidentifier></parentidentifier>
      <language></language>
      <type></type>
      <title></title>
      <abstract></abstract>
      <links/>
      <dates/>
      <fees></fees>
      <encoding></encoding>
      <crs>
        <spatialrefsys nativeFormat="Wkt">
          <wkt></wkt>
          <proj4></proj4>
          <srsid>0</srsid>
          <srid>0</srid>
          <authid></authid>
          <description></description>
          <projectionacronym></projectionacronym>
          <ellipsoidacronym></ellipsoidacronym>
          <geographicflag>false</geographicflag>
        </spatialrefsys>
      </crs>
      <extent/>
    </resourceMetadata>
    <items/>
    <flags>
      <Identifiable>1</Identifiable>
      <Removable>1</Removable>
      <Searchable>1</Searchable>
      <Private>0</Private>
    </flags>
    <customproperties>
      <Option/>
    </customproperties>
    <layerOpacity>1</layerOpacity>
    <blendMode>0</blendMode>
    <paintEffect/>
  </main-annotation-layer>
  <projectlayers/>
  <layerorder/>
  <labelEngineSettings/>
  <properties>
    <CopyrightLabel>
      <Enabled type="int">0</Enabled>
      <Label type="QString"></Label>
    </CopyrightLabel>
    <Digitizing>
      <AvoidIntersectionsMode type="int">0</AvoidIntersectionsMode>
    </Digitizing>
    <Gui>
      <CanvasColorBluePart type="int">255</CanvasColorBluePart>
      <CanvasColorGreenPart type="int">255</CanvasColorGreenPart>
      <CanvasColorRedPart type="int">255</CanvasColorRedPart>
      <SelectionColorAlphaPart type="int">255</SelectionColorAlphaPart>
      <SelectionColorBluePart type="int">0</SelectionColorBluePart>
      <SelectionColorGreenPart type="int">255</SelectionColorGreenPart>
      <SelectionColorRedPart type="int">255</SelectionColorRedPart>
    </Gui>
    <Legend>
      <filterByMap type="bool">false</filterByMap>
    </Legend>
    <Measure>
      <Ellipsoid type="QString">EPSG:7030</Ellipsoid>
    </Measure>
    <Measurement>
      <AreaUnits type="QString">m2</AreaUnits>
      <DistanceUnits type="QString">meters</DistanceUnits>
    </Measurement>
    <PAL>
      <CandidatesLinePerCM type="double">5</CandidatesLinePerCM>
      <CandidatesPolygonPerCM type="double">2.5</CandidatesPolygonPerCM>
      <DrawLabelMetrics type="bool">false</DrawLabelMetrics>
      <DrawRectOnly type="bool">false</DrawRectOnly>
      <DrawUnplaced type="bool">false</DrawUnplaced>
      <PlacementEngineVersion type="int">1</PlacementEngineVersion>
      <SearchMethod type="int">0</SearchMethod>
      <ShowingAllLabels type="bool">false</ShowingAllLabels>
      <ShowingCandidates type="bool">false</ShowingCandidates>
      <ShowingPartialsLabels type="bool">true</ShowingPartialsLabels>
      <TextFormat type="int">0</TextFormat>
      <UnplacedColor type="QString">255,0,0,255,rgb:1,0,0,1</UnplacedColor>
    </PAL>
    <Paths>
      <Absolute type="bool">false</Absolute>
    </Paths>
    <PositionPrecision>
      <Automatic type="bool">true</Automatic>
      <DecimalPlaces type="int">2</DecimalPlaces>
    </PositionPrecision>
    <SpatialRefSys>
      <ProjectionsEnabled type="int">1</ProjectionsEnabled>
    </SpatialRefSys>
  </properties>
  <dataDefinedServerProperties>
    <Option type="Map">
      <Option type="QString" name="name" value=""/>
      <Option name="properties"/>
      <Option type="QString" name="type" value="collection"/>
    </Option>
  </dataDefinedServerProperties>
  <visibility-presets/>
  <transformContext/>
  <projectMetadata>
    <identifier></identifier>
    <parentidentifier></parentidentifier>
    <language></language>
    <type></type>
    <title>$PROJECT_NAME</title>
    <abstract></abstract>
    <links/>
    <dates>
      <date type="Created" value="$QGIS_CREATION_DATE"/>
    </dates>
    <author>$QGIS_SAVE_USER</author>
    <creation>$QGIS_SAVE_DATETIME</creation>
  </projectMetadata>
  <Annotations/>
  <Layouts/>
  <mapViewDocks3D/>
  <Bookmarks/>
  <Sensors/>
  <ProjectViewSettings UseProjectScales="0" rotation="0">
    <Scales/>
  </ProjectViewSettings>
  <ProjectStyleSettings DefaultSymbolOpacity="1" projectStyleId="attachment:///NahsNZ_styles.db" colorModel="Rgb" RandomizeDefaultSymbolColor="1" iccProfileId="attachment:///">
    <databases/>
  </ProjectStyleSettings>
  <ProjectTimeSettings timeStepUnit="h" frameRate="1" timeStep="1" cumulativeTemporalRange="0" totalMovieFrames="100"/>
  <ElevationProperties FilterInvertSlider="0">
    <terrainProvider type="flat">
      <TerrainProvider offset="0" scale="1"/>
    </terrainProvider>
  </ElevationProperties>
  <ProjectDisplaySettings CoordinateAxisOrder="Default" CoordinateType="MapCrs">
    <BearingFormat id="bearing">
      <Option type="Map">
        <Option type="invalid" name="decimal_separator"/>
        <Option type="int" name="decimals" value="6"/>
        <Option type="int" name="direction_format" value="0"/>
        <Option type="int" name="rounding_type" value="0"/>
        <Option type="bool" name="show_plus" value="false"/>
        <Option type="bool" name="show_thousand_separator" value="true"/>
        <Option type="bool" name="show_trailing_zeros" value="false"/>
        <Option type="invalid" name="thousand_separator"/>
      </Option>
    </BearingFormat>
    <GeographicCoordinateFormat id="geographiccoordinate">
      <Option type="Map">
        <Option type="QString" name="angle_format" value="DecimalDegrees"/>
        <Option type="invalid" name="decimal_separator"/>
        <Option type="int" name="decimals" value="6"/>
        <Option type="int" name="rounding_type" value="0"/>
        <Option type="bool" name="show_leading_degree_zeros" value="false"/>
        <Option type="bool" name="show_leading_zeros" value="false"/>
        <Option type="bool" name="show_plus" value="false"/>
        <Option type="bool" name="show_suffix" value="false"/>
        <Option type="bool" name="show_thousand_separator" value="true"/>
        <Option type="bool" name="show_trailing_zeros" value="false"/>
        <Option type="invalid" name="thousand_separator"/>
      </Option>
    </GeographicCoordinateFormat>
    <CoordinateCustomCrs>
      <spatialrefsys nativeFormat="Wkt">
        <wkt>GEOGCRS["WGS 84",ENSEMBLE["World Geodetic System 1984 ensemble",MEMBER["World Geodetic System 1984 (Transit)"],MEMBER["World Geodetic System 1984 (G730)"],MEMBER["World Geodetic System 1984 (G873)"],MEMBER["World Geodetic System 1984 (G1150)"],MEMBER["World Geodetic System 1984 (G1674)"],MEMBER["World Geodetic System 1984 (G1762)"],ELLIPSOID["WGS 84",6378137,298.257223563,LENGTHUNIT["metre",1]],ENSEMBLEACCURACY[2.0]],PRIMEM["Greenwich",0,ANGLEUNIT["degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["geodetic latitude (Lat)",north,ORDER[1],ANGLEUNIT["degree",0.0174532925199433]],AXIS["geodetic longitude (Lon)",east,ORDER[2],ANGLEUNIT["degree",0.0174532925199433]],USAGE[SCOPE["Horizontal component of 3D system."],AREA["World."],BBOX[-90,-180,90,180]],ID["EPSG",4326]]</wkt>
        <proj4>+proj=longlat +datum=WGS84 +no_defs</proj4>
        <srsid>3452</srsid>
        <srid>4326</srid>
        <authid>EPSG:4326</authid>
        <description>WGS 84</description>
        <projectionacronym>longlat</projectionacronym>
        <ellipsoidacronym>EPSG:7030</ellipsoidacronym>
        <geographicflag>true</geographicflag>
      </spatialrefsys>
    </CoordinateCustomCrs>
  </ProjectDisplaySettings>
  <ProjectGpsSettings destinationFollowsActiveLayer="1" destinationLayer="" autoCommitFeatures="0" autoAddTrackVertices="0">
    <timeStampFields/>
  </ProjectGpsSettings>
</qgis>
EOF_QGIS
  gum format -- "- Created QGIS project file: **$QGIS_PROJ_FILE_ABS**"

  if gum confirm "Do you want to try launching QGIS with the new project file?"; then
    OS_TYPE=$(uname -s)
    LAUNCHED=false
    QGIS_OPEN_TARGET="$QGIS_PROJ_FILE_ABS"

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        if command -v open >/dev/null 2>&1; then
          echo "Attempting to launch QGIS for '$QGIS_OPEN_TARGET' using 'open'..."
          open "$QGIS_OPEN_TARGET" &>/dev/null &
          LAUNCHED=true
        else gum style --foreground="yellow" "Warning: 'open' command not found? Cannot open project."; fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        if command -v xdg-open >/dev/null 2>&1; then
          echo "Attempting to launch QGIS for '$QGIS_OPEN_TARGET' using 'xdg-open'..."
          xdg-open "$QGIS_OPEN_TARGET" &>/dev/null &
          LAUNCHED=true
        elif command -v qgis >/dev/null 2>&1; then
          echo "Attempting to launch QGIS for '$QGIS_OPEN_TARGET' using 'qgis' command..."
          qgis "$QGIS_OPEN_TARGET" &>/dev/null &
          LAUNCHED=true
        else gum style --foreground="yellow" "Warning: 'xdg-open' or 'qgis' command not found. Cannot open project."; fi
    else
        gum style --foreground="yellow" "Warning: Unsupported OS for automatic QGIS project opening via system handler."
    fi

    if ! $LAUNCHED; then
        gum style --foreground="yellow" "Could not automatically launch QGIS." \
                  "Please open manually: '$QGIS_OPEN_TARGET'"
    fi
  fi
fi

# 6. Ask to open R project in Editor (if R components were added)
if $ADD_R; then
  echo ""
  OPEN_WITH=$(gum choose "RStudio" "VSCode/Cursor" "Neither" --header "Open R project ($PROJECT_NAME.Rproj) with:" --height 5)
  R_OPEN_TARGET_FILE="$RPROJ_FILE_ABS"
  R_OPEN_TARGET_DIR="$PROJECT_ROOT_DIR"

  case "$OPEN_WITH" in
    "RStudio")
      OS_TYPE=$(uname -s)
      LAUNCH_CMD=""
      if [[ "$OS_TYPE" == "Darwin" ]]; then LAUNCH_CMD="open";
      elif [[ "$OS_TYPE" == "Linux" ]]; then LAUNCH_CMD="xdg-open";
      fi

      if [[ -n "$LAUNCH_CMD" ]] && command -v "$LAUNCH_CMD" >/dev/null 2>&1; then
        echo "Launching default application for '$R_OPEN_TARGET_FILE' using '$LAUNCH_CMD'..."
        "$LAUNCH_CMD" "$R_OPEN_TARGET_FILE" &>/dev/null &
      elif command -v rstudio >/dev/null 2>&1; then
        echo "Launching RStudio with '$R_OPEN_TARGET_FILE'..."
        rstudio "$R_OPEN_TARGET_FILE" &>/dev/null &
      else
        gum style --foreground="yellow" "Warning: Could not find suitable command (open, xdg-open, rstudio) to open R project automatically."
      fi
      ;;
    "VSCode/Cursor")
      EDITOR_CMD=""
      if command -v cursor >/dev/null 2>&1; then EDITOR_CMD="cursor";
      elif command -v code >/dev/null 2>&1; then EDITOR_CMD="code";
      fi

      if [[ -n "$EDITOR_CMD" ]]; then
        echo "Launching $EDITOR_CMD in project root directory ('$R_OPEN_TARGET_DIR')..."
        "$EDITOR_CMD" "$R_OPEN_TARGET_DIR" &>/dev/null &
      else
         gum style --foreground="yellow" "Warning: Neither 'cursor' nor 'code' command found. Cannot open project."
      fi
      ;;
    "Neither") echo "Okay, not opening any editor for the R project.";;
    *) echo "No editor selected for R project.";;
  esac
fi


# --- Final Summary ---
SUMMARY_MSG="Project setup complete."
if ! $ADD_R && ! $ADD_QGIS; then
    SUMMARY_MSG="Basic project structure and Git repo created. No specific R or QGIS components added."
fi

print_success "$SUMMARY_MSG" "$PROJECT_ROOT_DIR"

echo ""
echo "Current directory: $(pwd)"
echo "(Tip: Run script using 'source $0' or '. $0' to stay in this directory after it exits)"
echo "If you're on macOS and want advanced 'realpath' features (like -m), consider 'brew install coreutils' for 'grealpath'."


exit 0
