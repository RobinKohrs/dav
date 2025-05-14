#!/bin/bash

# --- Configuration ---
DEFAULT_N=20
DEFAULT_DIR="."
UNCHECKED_MARKER="[ ]"
CHECKED_MARKER="[x]"

# --- Helper Function: Show Usage ---
usage() {
  echo "Usage: $0 [-n <count>] [-d <directory>]"
  echo "       $0 -h|--help"
  echo
  echo "Lists the <count> largest files, allows selection with fzf (visual checkbox),"
  echo "and prompts for deletion with gum. No fzf preview."
  echo
  echo "Options:"
  echo "  -n <count>     Number of largest files to list for selection."
  echo "  -d <directory> The directory to search in. Defaults to '.' (current directory)."
  echo "  -h, --help     Show this help message."
  exit 1
}

# --- Check for CRITICAL dependencies (fzf, gum) ---
for cmd in fzf gum; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "--------------------------------------------------------------------------------" >&2
    echo "Error: Required command '$cmd' not found. This script cannot continue." >&2
    echo "Please install it:" >&2
    if [[ "$cmd" == "fzf" ]]; then
      echo "  - fzf: Visit https://github.com/junegunn/fzf for installation instructions." >&2
      echo "         (e.g., 'brew install fzf' on macOS)" >&2
    elif [[ "$cmd" == "gum" ]]; then
      echo "  - gum: Visit https://github.com/charmbracelet/gum for installation instructions." >&2
      echo "         (e.g., 'brew install gum' on macOS)" >&2
    fi
    echo "--------------------------------------------------------------------------------" >&2
    exit 1
  fi
done

# --- Check for OPTIONAL dependency (numfmt/gnumfmt for human-readable sizes) ---
NUMFMT_CMD=""
if command -v numfmt &> /dev/null; then
  NUMFMT_CMD="numfmt"
elif command -v gnumfmt &> /dev/null; then # GNU numfmt, common on macOS via Homebrew's coreutils
  NUMFMT_CMD="gnumfmt"
fi

if [[ -z "$NUMFMT_CMD" ]]; then
  echo "--------------------------------------------------------------------------------" >&2
  echo "INFO: Utility 'numfmt' (or 'gnumfmt') not found." >&2
  echo "File sizes will be displayed in raw bytes, which might be less readable." >&2
  echo "The script will still function correctly." >&2
  if [[ "$(uname)" == "Darwin" ]]; then # macOS specific advice
    echo "" >&2
    echo "To get human-readable sizes (e.g., 1.2K, 3.4M, 5.6G) on macOS," >&2
    echo "you can install 'gnumfmt' (part of GNU coreutils) via Homebrew:" >&2
    echo "  brew install coreutils" >&2
  else # General advice for other Linux/Unix systems
    echo "" >&2
    echo "To get human-readable sizes, consider installing 'numfmt'," >&2
    echo "which is usually part of the 'coreutils' package for your distribution." >&2
    echo "(e.g., 'sudo apt install coreutils' or 'sudo yum install coreutils')" >&2
  fi
  echo "--------------------------------------------------------------------------------" >&2
  # Wait a moment so the user has a chance to see the message if it scrolls by fast
  # sleep 1 # Optional: uncomment if you want a slight pause
fi

# --- Parse Command Line Arguments ---
N_FILES=$DEFAULT_N
TARGET_DIR=$DEFAULT_DIR

while getopts ":n:d:h" opt; do
  case $opt in
    n)
      if [[ "$OPTARG" =~ ^[0-9]+$ && "$OPTARG" -gt 0 ]]; then
        N_FILES=$OPTARG
      else
        echo "Error: -n value must be a positive integer." >&2
        usage
      fi
      ;;
    d)
      TARGET_DIR=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ $# -gt 0 ]; then
    echo "Error: Too many arguments. Use -d for directory if needed." >&2
    usage
fi

# --- Validate Target Directory ---
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' not found." >&2
  exit 1
fi

# --- Temporary files ---
STATE_FILE=$(mktemp "/tmp/fzf_bigdel_state.XXXXXX")
TMP_FILE_LIST=$(mktemp "/tmp/fzf_bigdel_tmplist.XXXXXX")
# Ensure cleanup
trap 'rm -f "$STATE_FILE" "$TMP_FILE_LIST"' EXIT


echo "Searching for files in '$TARGET_DIR'..."
# --- Find files and their sizes, store in TMP_FILE_LIST ---
(
  find "$TARGET_DIR" -type f -print0 2>/dev/null | while IFS= read -r -d $'\0' filepath_raw_loop; do
    if [[ -n "$filepath_raw_loop" ]]; then
      size_bytes_loop=""
      if [[ "$(uname)" == "Darwin" ]]; then
        size_bytes_loop=$(stat -f "%z" -- "$filepath_raw_loop" 2>/dev/null)
      else
        size_bytes_loop=$(stat -c "%s" -- "$filepath_raw_loop" 2>/dev/null)
      fi

      if [[ -n "$size_bytes_loop" && "$size_bytes_loop" =~ ^[0-9]+$ ]]; then
        echo -e "${size_bytes_loop}\t${filepath_raw_loop}"
      else
        echo "Warning: Could not get size for '$filepath_raw_loop'" >&2
      fi
    fi
  done
) > "$TMP_FILE_LIST"


if [ ! -s "$TMP_FILE_LIST" ]; then
    actual_file_count=$(grep -c $'\t' "$TMP_FILE_LIST" 2>/dev/null || echo 0)
    if [ "$actual_file_count" -eq 0 ]; then
        echo "No files found or processed in '$TARGET_DIR'."
        exit 0
    fi
fi

echo "Preparing list for fzf (top $N_FILES)..."
# --- Sort, Format, and Populate Initial State File from TMP_FILE_LIST ---
> "$STATE_FILE"
declare -a initial_lines_for_state_file

while IFS=$'\t' read -r size_bytes filepath_raw; do
  if [[ -n "$filepath_raw" ]]; then
    human_size=""
    if [[ -n "$NUMFMT_CMD" ]]; then # Use the NUMFMT_CMD determined earlier
      human_size=$($NUMFMT_CMD --to=iec-i --suffix=B --padding=7 --format="%.1f" "$size_bytes" 2>/dev/null || echo "${size_bytes}B")
    else
      human_size=$(printf "%7sB" "$size_bytes")
    fi
    initial_lines_for_state_file+=("$(printf "%s %s\t%s" "$UNCHECKED_MARKER" "$human_size" "$filepath_raw")")
  fi
done < <(sort -k1,1nr "$TMP_FILE_LIST" | head -n "$N_FILES")

if [ ${#initial_lines_for_state_file[@]} -eq 0 ]; then
  echo "No files found or processed after sorting/filtering in '$TARGET_DIR'."
  exit 0
fi

printf "%s\n" "${initial_lines_for_state_file[@]}" > "$STATE_FILE"

# --- Helper function to toggle selection state in the STATE_FILE ---
toggle_fzf_line_selection() {
    local line_number_to_toggle="$1"
    local state_file_path="$2"
    local sed_line_number=$((line_number_to_toggle + 1))
    
    IFS= read -r current_line_in_state < <(sed -n "${sed_line_number}p" "$state_file_path")

    local new_line_for_state
    if [[ "$current_line_in_state" == "$CHECKED_MARKER "* ]]; then
        new_line_for_state="${UNCHECKED_MARKER} ${current_line_in_state#"$CHECKED_MARKER "}"
    elif [[ "$current_line_in_state" == "$UNCHECKED_MARKER "* ]]; then
        new_line_for_state="${CHECKED_MARKER} ${current_line_in_state#"$UNCHECKED_MARKER "}"
    else
        echo "Error: Line does not start with a known marker: $current_line_in_state" >&2
        return 1
    fi

    local safe_new_line_for_state
    safe_new_line_for_state=$(echo "$new_line_for_state" | sed -e 's/\\/\\\\/g' -e 's/#/\\#/g')

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "${sed_line_number}s#.*#${safe_new_line_for_state}#" "$state_file_path"
    else
        sed -i "${sed_line_number}s#.*#${safe_new_line_for_state}#" "$state_file_path"
    fi
}
export -f toggle_fzf_line_selection
export CHECKED_MARKER UNCHECKED_MARKER

# Helper function to select/deselect all
toggle_all_fzf_lines() {
    local target_marker="$1"
    local current_marker="$2"
    local state_file_path="$3"

    local escaped_current_marker regex_current_marker
    escaped_current_marker=$(printf '%s' "$current_marker" | sed 's/[].[^$\\*]/\\&/g')
    regex_current_marker="^${escaped_current_marker}"
    local replacement_marker="$target_marker"

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/${regex_current_marker}/${replacement_marker}/" "$state_file_path"
    else
        sed -i "s/${regex_current_marker}/${replacement_marker}/" "$state_file_path"
    fi
}
export -f toggle_all_fzf_lines

echo "Launching fzf for selection..."
# --- fzf Selection ---
fzf --ansi \
    --header="SPACE to toggle, ENTER to confirm, CTRL-A all, CTRL-D none, CTRL-C cancel" \
    --height=${FZF_HEIGHT:-40%} \
    --no-mouse \
    --no-preview \
    --delimiter='\t' \
    --with-nth='1..' \
    --bind="space:execute-silent(bash -c 'toggle_fzf_line_selection {n} \"$STATE_FILE\"')+reload(cat \"$STATE_FILE\")" \
    --bind="ctrl-a:execute-silent(bash -c 'toggle_all_fzf_lines \"$CHECKED_MARKER\" \"$UNCHECKED_MARKER\" \"$STATE_FILE\"')+reload(cat \"$STATE_FILE\")" \
    --bind="ctrl-d:execute-silent(bash -c 'toggle_all_fzf_lines \"$UNCHECKED_MARKER\" \"$CHECKED_MARKER\" \"$STATE_FILE\"')+reload(cat \"$STATE_FILE\")" \
    --expect=enter \
    < "$STATE_FILE" > /dev/null
fzf_exit_code=$?

if [ $fzf_exit_code -eq 130 ]; then
  echo "Selection cancelled."
  exit 0
elif [ $fzf_exit_code -ne 0 ]; then
  echo "fzf exited (code: $fzf_exit_code). Assuming cancellation or error."
  exit 1
fi

# --- Extract selected filepaths from the STATE_FILE ---
declare -a files_to_delete
while IFS= read -r line_from_state; do
  if [[ "$line_from_state" == "$CHECKED_MARKER"* ]]; then
    filepath_selected=$(echo "$line_from_state" | cut -d$'\t' -f2-)
    if [[ -n "$filepath_selected" ]]; then
      files_to_delete+=("$filepath_selected")
    else
      echo "Warning: Could not extract filepath from selected line: $line_from_state" >&2
    fi
  fi
done < "$STATE_FILE"

if [ ${#files_to_delete[@]} -eq 0 ]; then
  echo "No files were selected for deletion."
  exit 0
fi

# --- Gum Confirmation ---
echo
echo "You have selected the following ${#files_to_delete[@]} file(s) for DELETION:"
printf "  - %s\n" "${files_to_delete[@]}"
echo

if gum confirm "Are you sure you want to PERMANENTLY DELETE these files?" --affirmative "Delete" --negative "Cancel"; then
  echo "Deleting selected files..."
  deleted_count=0
  error_count=0
  for file_to_rm in "${files_to_delete[@]}"; do
    if rm -vf -- "$file_to_rm"; then
      ((deleted_count++))
    else
      echo "Error deleting '$file_to_rm'" >&2
      ((error_count++))
    fi
  done
  echo "--------------------------------------------------"
  echo "Deletion complete."
  echo "  Successfully deleted: $deleted_count file(s)."
  if [ "$error_count" -gt 0 ]; then
    echo "  Failed to delete:   $error_count file(s)."
  fi
else
  echo "Deletion cancelled by user."
fi

echo "Done."