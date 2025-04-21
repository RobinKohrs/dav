#!/usr/bin/env bash

# --- Configuration ---
SEARCH_START_DIR="${PROJECT_BASE_DIR:-$HOME}"
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
            "Success!" "$1" "Project created at: $(gum style --bold "$2")"
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

# --- Main Script ---

# 1. Get Project Name
PROJECT_NAME=$(gum input --placeholder "Enter a name for your project (e.g., 'urban_growth_analysis')")
if [ -z "$PROJECT_NAME" ]; then
  print_error "Project name cannot be empty."
fi
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr ' ' '_' | sed 's:/*$::')
gum format -- "- Project name set to: **$PROJECT_NAME**"

# 2. Get Project Location (Parent Directory) using fzf
gum format -- "- Preparing location selection..."

# Start spinner in background and get its PID
gum spin --spinner="line" --title="Searching for directories (max depth $FIND_MAX_DEPTH from $SEARCH_START_DIR)..." -- sleep infinity &
SPIN_PID=$!
trap 'kill $SPIN_PID >/dev/null 2>&1' EXIT SIGINT SIGTERM

# Run find | fzf and capture output
FZF_HEADER="Navigate & Select PARENT directory"
PARENT_DIR=$(find "$SEARCH_START_DIR" -maxdepth "$FIND_MAX_DEPTH" -type d \
  \( -name ".git" -o -name "node_modules" -o -name ".cache" -o -name "venv" -o -name ".venv" -o -path "*/.*" \) -prune \
  -o -print 2>/dev/null | fzf --header="$FZF_HEADER" \
                               --height="$FZF_HEIGHT" --border \
                               --preview='ls -lah --color=always {} | head -n 20' --exit-0 --select-1 --no-multi)
FZF_EXIT_CODE=$?

# Stop the spinner gracefully
kill $SPIN_PID >/dev/null 2>&1
wait $SPIN_PID 2>/dev/null
trap - EXIT SIGINT SIGTERM

# Check fzf exit code AND if the selection is empty
if [ $FZF_EXIT_CODE -ne 0 ] || [ -z "$PARENT_DIR" ]; then
    print_error "No parent directory selected or selection cancelled. Aborting."
fi

# Verify it's actually a directory
if [ ! -d "$PARENT_DIR" ]; then
  print_error "The selected path '$PARENT_DIR' is not a valid directory."
fi

# Construct the full project path
PROJECT_PATH="$PARENT_DIR/$PROJECT_NAME"
gum format -- "- Project root will be: **$PROJECT_PATH**"

# 3. Check if project directory already exists
if [ -e "$PROJECT_PATH" ]; then
  gum confirm "Directory '$PROJECT_PATH' already exists. Continue and potentially add files?" --default=false || {
    echo "Operation cancelled by user."
    exit 0
  }
  echo "Proceeding with existing directory..."
else
  mkdir -p "$PROJECT_PATH" || print_error "Failed to create directory '$PROJECT_PATH'. Check permissions."
fi


# --- Git Initialization and Base Setup ---
cd "$PROJECT_PATH" || print_error "Failed to change directory to $PROJECT_PATH"

# 4. Initialize Git Repository (if not already one)
if [ ! -d ".git" ]; then
    gum spin --spinner="dot" --title="Initializing Git repository..." -- \
    git init -q || print_error "Failed to initialize Git repository."
    gum format -- "- Initialized Git repository."
else
    gum format -- "- Git repository already exists."
fi

# 5. Create comprehensive .gitignore
gum format -- "- Creating/Updating .gitignore..."
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

# --- R ---
.Rhistory
.Rapp.history
.RData
.Ruserdata
R/.Rproj.user/
R/*_cache/
R/cache/
.Renviron
.httr-oauth
rsconnect/

# --- QGIS ---
qgis/*.qgs~
qgis/*.qgz~

# --- Python ---
.venv/
venv/
*.pyc
__pycache__/
.env

# --- Data (Consider uncommenting or being more specific) ---
# R/data_raw/
# R/data_output/
# qgis/data_raw/
# qgis/data_output/

# --- Large Files (Consider Git LFS: https://git-lfs.github.com/) ---
# *.tif
# *.gpkg
# *.shp
# *.parquet
# *.feather
# *.rds
# *.pdf
# *.pptx
# *.docx

# --- Secrets (NEVER commit credentials!) ---
*.cred
*.secret
credentials.*
secret.*
*key*
*token*

# --- OS Specific ---
desktop.ini

# --- IDEs ---
.vscode/
.idea/
*.swp
*.swo
EOF

# --- Optional Components ---

# 6. Ask about R components
ADD_R=false # Flag to track if R components were added
if gum confirm "Add R project components?"; then
  ADD_R=true
  gum spin --spinner="dot" --title="Setting up R components..." -- sleep 0.5

  mkdir -p "R/analysis"
  mkdir -p "R/data_raw"
  mkdir -p "R/data_output"

  RPROJ_FILE_RELATIVE="R/$PROJECT_NAME.Rproj" # Relative path needed later
  echo "Creating R project file: $RPROJ_FILE_RELATIVE"
  cat << EOF_RPROJ > "$RPROJ_FILE_RELATIVE"
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

# Project located in: R/
# Analysis scripts/docs likely in R/analysis/
# Raw data in R/data_raw/, Processed data in R/data_output/
# Use here::here() for robust paths relative to the project root ($PROJECT_PATH)
EOF_RPROJ
  gum format -- "- Added R components in **R/** subdirectory (analysis, data_raw, data_output)."

  # --- EDITOR CHOICE MOVED FROM HERE ---

fi # End of ADD_R block

# 7. Ask about QGIS components
ADD_QGIS=false # Flag (optional, but good practice)
if gum confirm "Add QGIS project components?"; then
  ADD_QGIS=true
  gum spin --spinner="line" --title="Setting up QGIS components..." -- sleep 0.5

  mkdir -p "qgis/data_raw/polygon"
  mkdir -p "qgis/data_raw/raster"
  mkdir -p "qgis/data_raw/tabular"
  mkdir -p "qgis/data_output"
  mkdir -p "qgis/graphic_output"
  mkdir -p "qgis/scripts"

  gum format -- "- Added QGIS components in **qgis/** subdirectory."

  # Create the QGIS project file (.qgs) with provided template
  QGIS_PROJ_FILE_RELATIVE="qgis/$PROJECT_NAME.qgs"
  echo "Creating QGIS project file: $QGIS_PROJ_FILE_RELATIVE"
  # Note: Using the provided template, only substituting projectname
  cat << EOF_QGIS > "$QGIS_PROJ_FILE_RELATIVE"
<!DOCTYPE qgis PUBLIC 'http://mrcc.com/qgis.dtd' 'SYSTEM'>
<qgis saveUser="rk" saveDateTime="2025-04-21T14:41:32" version="3.40.3-Bratislava" projectname="$PROJECT_NAME" saveUserFull="Robin Kohrs">
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
    <id>Annotations_3c7cb078_5a7a_4e1a_b46b_490a1f3cf8fe</id>
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
    <title></title>
    <abstract></abstract>
    <links/>
    <dates>
      <date type="Created" value="2025-04-21T14:41:10"/>
    </dates>
    <author>Robin Kohrs</author>
    <creation>2025-04-21T14:41:10</creation>
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
  gum format -- "- Created QGIS project file: **$QGIS_PROJ_FILE_RELATIVE**"

  if gum confirm "Do you want to try launching QGIS with the new project file?"; then
    OS_TYPE=$(uname -s)
    LAUNCHED=false

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS
        if command -v open >/dev/null 2>&1; then
          echo "Attempting to launch QGIS for '$QGIS_PROJ_FILE_RELATIVE' using 'open'..."
          open "$QGIS_PROJ_FILE_RELATIVE" &>/dev/null &
          LAUNCHED=true
        else
           gum style --foreground="yellow" "Warning: 'open' command not found? Cannot open project."
        fi
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Linux
        if command -v xdg-open >/dev/null 2>&1; then
          echo "Attempting to launch QGIS for '$QGIS_PROJ_FILE_RELATIVE' using 'xdg-open'..."
          xdg-open "$QGIS_PROJ_FILE_RELATIVE" &>/dev/null &
          LAUNCHED=true
        else
          gum style --foreground="yellow" "Warning: 'xdg-open' command not found in PATH. Cannot open project."
        fi
    else
        gum style --foreground="yellow" "Warning: Unsupported OS for automatic QGIS project opening via system handler."
    fi

    # Final warning if the specific OS handler wasn't found/used
    if ! $LAUNCHED; then
        gum style --foreground="yellow" "Could not automatically launch QGIS project using system handler ('open' or 'xdg-open')." \
                  "Please open the file manually:" \
                  "'$PROJECT_PATH/$QGIS_PROJ_FILE_RELATIVE'"
    fi
  fi
fi # End of ADD_QGIS block


# 8. Ask to open R project in Editor (if R components were added)
if $ADD_R; then
  echo "" # Add a newline for spacing
  OPEN_WITH=$(gum choose "RStudio" "Cursor" "Neither" --header "Open R sub-project (${PROJECT_NAME}/R) with:" --height 5)

  case "$OPEN_WITH" in
    "RStudio")
      # Use the relative path to the .Rproj file
      OS_TYPE=$(uname -s)
      if [[ "$OS_TYPE" == "Darwin" ]]; then
        # macOS
        if command -v open >/dev/null 2>&1; then
          echo "Launching default application for '$RPROJ_FILE_RELATIVE' using 'open'..."
          open "$RPROJ_FILE_RELATIVE" &>/dev/null &
        else
           # Should generally not happen on macOS
           gum style --foreground="yellow" "Warning: 'open' command not found? Cannot open project."
        fi
      elif [[ "$OS_TYPE" == "Linux" ]]; then
        # Linux
        if command -v xdg-open >/dev/null 2>&1; then
          echo "Launching default application for '$RPROJ_FILE_RELATIVE' using 'xdg-open'..."
          xdg-open "$RPROJ_FILE_RELATIVE" &>/dev/null &
        else
          gum style --foreground="yellow" "Warning: 'xdg-open' command not found in PATH. Cannot open project."
        fi
      else
        # Fallback for other OSes (like Windows via Git Bash/WSL without xdg-utils)
        # Try the original rstudio command as a last resort
      if command -v rstudio >/dev/null 2>&1; then
          echo "Launching RStudio with '$RPROJ_FILE_RELATIVE' (OS detection fallback)..."
        rstudio "$RPROJ_FILE_RELATIVE" &>/dev/null &
      else
          gum style --foreground="yellow" "Warning: Neither 'open' (Mac), 'xdg-open' (Linux), nor 'rstudio' found in PATH. Cannot open project automatically."
        fi
      fi
      ;;
    "Cursor")
      # Target the R subdirectory directly
      if command -v cursor >/dev/null 2>&1; then
        echo "Launching Cursor in R subdirectory ('R')..."
        cursor R &>/dev/null & # Open the R directory relative to current dir ($PROJECT_PATH)
      else
         gum style --foreground="yellow" "Warning: 'cursor' command not found in PATH. Cannot open project."
      fi
      ;;
    "Neither")
      echo "Okay, not opening any editor for the R project."
      ;;
    *)
      echo "No editor selected."
      ;;
  esac
fi


# --- Final Summary ---
SUMMARY_MSG="Project setup complete."
if ! $ADD_R && ! $ADD_QGIS; then
    SUMMARY_MSG="Basic project structure and Git repo created. No specific R or QGIS components added."
fi

print_success "$SUMMARY_MSG" "$(pwd)" # Use pwd as we already cd'd

# Optional: Offer to change directory (needs sourcing to persist)
echo ""
echo "Current directory: $(pwd)"
echo "(Run script using 'source $0' or '. $0' to stay in this directory after the script exits)"

exit 0