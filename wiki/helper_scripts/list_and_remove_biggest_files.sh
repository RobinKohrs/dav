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

# --- Check for dependencies ---
for cmd in fzf gum; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "Error: Required command '$cmd' not found. Please install it." >&2
    exit 1
  fi
done

NUMFMT_CMD="numfmt"
if ! command -v numfmt &> /dev/null && command -v gnumfmt &> /dev/null; then
  NUMFMT_CMD="gnumfmt"
elif ! command -v numfmt &> /dev/null && ! command -v gnumfmt &> /dev/null; then
  echo "Warning: 'numfmt' (or 'gnumfmt') not found. Sizes will be in bytes." >&2
  NUMFMT_CMD=""
fi

# --- Validate Target Directory ---
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' not found." >&2
  exit 1
fi

# --- Temporary file for fzf state ---
# This file will store lines like: "[ ] 1.2G      /path/to/file" (size is padded)
# The first part is the "checkbox", then human size, then tab, then actual path.
STATE_FILE=$(mktemp "/tmp/fzf_bigdel_state.XXXXXX")
# Ensure cleanup of the state file
trap 'rm -f "$STATE_FILE"' EXIT

echo "Searching for the largest files in '$TARGET_DIR'..."
echo "Preparing list for fzf (top $N_FILES)..."

# --- Find, Sort, Format, and Populate Initial State File ---
> "$STATE_FILE" # Clear or create the state file
declare -a initial_lines_for_state_file

# Process find output
while IFS=$'\t' read -r size_bytes filepath_raw; do
  if [[ -n "$filepath_raw" ]]; then
    human_size=""
    if [[ -n "$NUMFMT_CMD" ]]; then
      # Pad size for better alignment. Adjust padding (e.g., --padding=7) if needed.
      human_size=$($NUMFMT_CMD --to=iec-i --suffix=B --padding=7 --format="%.1f" "$size_bytes" 2>/dev/null || echo "${size_bytes}B")
    else
      human_size=$(printf "%7sB" "$size_bytes") # Basic padding for bytes
    fi
    # Format: "[ ] PADDED_HUMAN_SIZE\tACTUAL_FILEPATH"
    # The tab is important so we can extract the path later reliably.
    initial_lines_for_state_file+=("$(printf "%s %s\t%s" "$UNCHECKED_MARKER" "$human_size" "$filepath_raw")")
  fi
done < <(find "$TARGET_DIR" -type f -printf "%s\t%p\n" 2>/dev/null | sort -k1,1nr | head -n "$N_FILES")


if [ ${#initial_lines_for_state_file[@]} -eq 0 ]; then
  echo "No files found or processed in '$TARGET_DIR'."
  exit 0
fi

# Write initial state to the state file
printf "%s\n" "${initial_lines_for_state_file[@]}" > "$STATE_FILE"


# --- Helper function to toggle selection state in the STATE_FILE ---
# This function will be called by fzf's execute binding.
toggle_fzf_line_selection() {
    local line_number_to_toggle="$1" # 0-based line number from fzf's {n}
    local state_file_path="$2"
    
    # Convert to 1-based for sed
    local sed_line_number=$((line_number_to_toggle + 1))
    
    # Debug output
    echo "Toggling line $sed_line_number in $state_file_path" >&2

    # Read the specific line from the state file
    # Add -r to read to prevent backslash interpretation
    IFS= read -r current_line_in_state < <(sed -n "${sed_line_number}p" "$state_file_path")
    echo "Current line: $current_line_in_state" >&2

    local new_line_for_state
    # Toggle the marker. Use fixed string comparison for robustness.
    # Include the space after the marker in the comparison
    if [[ "$current_line_in_state" == "$CHECKED_MARKER "* ]]; then
        new_line_for_state="${UNCHECKED_MARKER} ${current_line_in_state#"$CHECKED_MARKER "}"
        echo "Toggling to unchecked" >&2
    elif [[ "$current_line_in_state" == "$UNCHECKED_MARKER "* ]]; then
        new_line_for_state="${CHECKED_MARKER} ${current_line_in_state#"$UNCHECKED_MARKER "}"
        echo "Toggling to checked" >&2
    else
        # Should not happen if markers are consistent
        echo "Error: Line does not start with a known marker: $current_line_in_state" >&2
        return 1 # Prevent modification
    fi

    # Escape for sed 's' command replacement string: primarily backslashes and the delimiter
    # Using # as delimiter, so escape # and \
    local safe_new_line_for_state
    safe_new_line_for_state=$(echo "$new_line_for_state" | sed -e 's/\\/\\\\/g' -e 's/#/\\#/g')
    echo "New line will be: $new_line_for_state" >&2

    # Update the line in the state file. Use # as sed delimiter.
    sed -i "${sed_line_number}s#.*#${safe_new_line_for_state}#" "$state_file_path"
    echo "Line updated" >&2
}

# Export the function and variables needed by it
export -f toggle_fzf_line_selection
export CHECKED_MARKER UNCHECKED_MARKER

# Helper function to select/deselect all
toggle_all_fzf_lines() {
    local target_marker="$1" # The marker to set ([x] or [ ])
    local current_marker="$2" # The marker to find and replace
    local state_file_path="$3"

    # sed -i "s/^\[ \] /[x] /" "$STATE_FILE" -> wrong, CHECKED_MARKER is var
    # Need to escape the markers for sed's regex part
    local escaped_current_marker regex_current_marker
    escaped_current_marker=$(printf '%s' "$current_marker" | sed 's/[].[^$\\*]/\\&/g') # Escape regex special chars
    regex_current_marker="^${escaped_current_marker}"

    local replacement_marker
    replacement_marker="$target_marker"

    sed -i "s/${regex_current_marker}/${replacement_marker}/" "$state_file_path"
}
export -f toggle_all_fzf_lines


echo "Launching fzf for selection..."

# --- fzf Selection ---
# Capture fzf's exit code to see if it was cancelled.
# fzf reads from STATE_FILE. On Enter, it will print the key and the *final highlighted line*.
# We don't really need fzf's stdout if we just re-read the state file on successful exit.
# But --expect means it will print something, so direct to /dev/null if not used.
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
    < "$STATE_FILE" > /dev/null # Discard fzf's stdout as we parse STATE_FILE
fzf_exit_code=$?

# Check fzf exit code
# 0: Normal exit (e.g., Enter key from --expect)
# 1: No match (not applicable here as we provide all lines)
# 130: Cancelled with Ctrl-C or Esc (or other signal)
if [ $fzf_exit_code -eq 130 ]; then
  echo "Selection cancelled."
  exit 0
elif [ $fzf_exit_code -ne 0 ]; then
  # If --expect=enter, fzf prints "enter" then the line. Exit code is 0.
  # If other keys are specified in --expect, their exit codes may vary or be 0.
  # If fzf simply exits due to an error or unexpected signal, it might be non-zero other than 130.
  echo "fzf exited (code: $fzf_exit_code). Assuming cancellation or error."
  exit 1
fi

# --- Extract selected filepaths from the STATE_FILE ---
declare -a files_to_delete
while IFS= read -r line_from_state; do # Use IFS= and -r for robust line reading
  if [[ "$line_from_state" == "$CHECKED_MARKER"* ]]; then
    # Extract the path part: everything after the first tab.
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
for file_path_to_display in "${files_to_delete[@]}"; do
    echo "  - $file_path_to_display"
done
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
# trap will clean up $STATE_FILE