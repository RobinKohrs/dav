#!/usr/bin/env bash

# Script to scaffold a Quarto project or single document with interactive prompts.
# Uses fzf for selection menus.

# --- Configuration ---
# Add more formats or project types as needed
declare -a formats=("html" "pdf" "docx" "revealjs" "website" "book" "beamer")
# You could potentially list templates stored elsewhere in your package here too

# --- Helper Functions ---
function check_dependency {
    # Checks if a command is available in the PATH
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Required command '$1' not found."
        echo "Please install it."
        # Provide specific install hints if possible
        if [[ "$1" == "fzf" ]]; then
            echo "  macOS: brew install fzf"
            echo "  Debian/Ubuntu: sudo apt install fzf"
            echo "  Fedora: sudo dnf install fzf"
        elif [[ "$1" == "quarto" ]]; then
            echo "  Download from https://quarto.org/docs/get-started/"
        fi
        exit 1
    fi
}

function is_format_selected {
    # Checks if a specific format string exists in the selected_formats array
    local format_to_check=$1
    local selected_array=("${@:2}") # Pass the array elements starting from the second argument
    for selected in "${selected_array[@]}"; do
        if [[ "$selected" == "$format_to_check" ]]; then
            return 0 # Found (true in shell return codes)
        fi
    done
    return 1 # Not found (false in shell return codes)
}

# --- Check Dependencies ---
check_dependency "fzf"
check_dependency "quarto" # Good practice to ensure quarto is available

# --- Get User Input ---
echo "Quarto Project Scaffolder"
echo "-------------------------"

# Project Name
read -p "Enter the name for your new Quarto project/document folder: " project_name

# Validate name (basic check: not empty)
if [[ -z "$project_name" ]]; then
    echo "Error: Project name cannot be empty."
    exit 1
fi

# Check if directory already exists
if [[ -d "$project_name" ]]; then
    read -p "Warning: Directory '$project_name' already exists. Overwrite? (y/N): " overwrite_confirm
    if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    else
        echo "Overwriting existing directory '$project_name'..."
        rm -rf "$project_name" # Use with caution!
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to remove existing directory '$project_name'."
            exit 1
        fi
    fi
fi


# Select Format(s) using fzf
# Use --height with a number slightly larger than the number of options
# Use --multi to allow multiple selections (use TAB to mark, Enter to confirm)
fzf_height=$((${#formats[@]} + 3)) # Add padding for prompt/border
echo "Select output format(s) (use Arrow Keys, TAB/Shift+TAB to select, Enter to confirm):"

# Initialize an empty array for selected formats
selected_formats=()

# Use a while loop to read lines from fzf output into the array (Bash 3+ compatible)
while IFS= read -r line; do
    # Append the line read to the array
    selected_formats+=("$line")
done < <(printf "%s\n" "${formats[@]}" | fzf --prompt="Format(s): " --height="$fzf_height" --border --cycle --multi)

# Check fzf's exit status immediately after the command substitution finishes
fzf_exit_status=$?

# Handle fzf cancellation (exit status 130) or errors
if [[ $fzf_exit_status -ne 0 && $fzf_exit_status -ne 130 ]]; then
    # Report actual fzf errors (other than cancellation)
    echo "Error running fzf (Exit status: $fzf_exit_status)."
    exit 1
elif [[ ${#selected_formats[@]} -eq 0 ]]; then
    # Array is empty, likely means cancellation (ESC or Ctrl+C) or just hitting Enter
    echo "Operation cancelled. No formats selected."
    exit 1
fi

# If we reach here, selection was successful
echo "Selected format(s): ${selected_formats[*]}" # Show selected formats


# --- HTML Specific Questions ---
html_toc_enabled="false" # Default
html_css_path=""
html_options_yaml=""

# Use the helper function to check if 'html' is in the array
if is_format_selected "html" "${selected_formats[@]}"; then
    echo "--- HTML Options ---"
    read -p "Include Table of Contents (TOC)? (y/N): " use_toc
    if [[ "$use_toc" =~ ^[Yy]$ ]]; then
        html_toc_enabled="true"
        html_options_yaml+="    toc: true\n" # Indentation for YAML
    fi

    read -p "Use a custom CSS file? (y/N): " use_css
    if [[ "$use_css" =~ ^[Yy]$ ]]; then
        read -p "Enter path to custom CSS file (relative to '$project_name/'): " css_path_input
        # Basic check if path provided
        if [[ -n "$css_path_input" ]]; then
             # Clean up potential leading/trailing quotes if user added them
            css_path_input=$(echo "$css_path_input" | sed -e 's/^"//' -e 's/"$//')
            html_css_path="$css_path_input"
            html_options_yaml+="    css: $html_css_path\n" # Indentation for YAML
        else
            echo "No CSS path provided, skipping custom CSS."
        fi
    fi
fi


# --- Create Project Structure ---
echo "" # Newline for clarity
echo "Creating project structure in '$project_name'..."

# Create directory; -p ensures no error if it somehow exists and allows parent creation
mkdir -p "$project_name"
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create directory '$project_name'."
    exit 1
fi

cd "$project_name" || exit 1 # Move into the new directory, exit if failed


# --- Generate YAML ---
main_file_name="index.qmd" # Default for projects or single docs
project_type=""
is_project=0

# Check if a project type (website, book) was selected
# Note: Assumes only one project type can be selected meaningfully at once.
# If multiple project types were somehow selected, this picks the first one found.
for fmt in "${selected_formats[@]}"; do
    if [[ "$fmt" == "website" || "$fmt" == "book" ]]; then
        project_type="$fmt"
        is_project=1
        break # Stop after finding the first project type
    fi
done


# --- Build the format YAML block ---
format_yaml_block=""
# Check if we need the complex multi-format structure
if [[ ${#selected_formats[@]} -gt 1 ]] || [[ $is_project -eq 1 ]] || [[ -n "$html_options_yaml" ]]; then
    # Complex case: multiple formats, project, or HTML options needed
    format_yaml_block="format:"
    for fmt in "${selected_formats[@]}"; do
        # Add the format key with indentation
        # Skip project types from the format list itself in _quarto.yml
        if [[ "$fmt" == "website" && $is_project -eq 1 ]] || [[ "$fmt" == "book" && $is_project -eq 1 ]]; then
            continue # Don't list website/book under 'format:' if it's the project type
        fi

        format_yaml_block+="\n  $fmt:"
        sub_options_added=0
        if [[ "$fmt" == "html" ]] && [[ -n "$html_options_yaml" ]]; then
             # Append HTML specific options IF they exist, with extra indent
            format_yaml_block+="\n$(echo -e "${html_options_yaml}" | sed 's/^/    /')" # Add 2 extra spaces (4 total)
            sub_options_added=1
        elif [[ "$fmt" == "pdf" ]]; then
            # Add a common default option for PDF if you like
            format_yaml_block+="\n    documentclass: article"
            format_yaml_block+="\n    toc: true" # Example: enable TOC for PDF too
            sub_options_added=1
        # Add elif blocks here for default options for other formats if desired
        # Example:
        # elif [[ "$fmt" == "revealjs" ]]; then
        #     format_yaml_block+="\n    theme: simple"
        #     sub_options_added=1
        fi

        # Add placeholder if no sub-options were added for this format key
        # This ensures valid YAML (key cannot be empty)
        if [[ $sub_options_added -eq 0 ]]; then
            format_yaml_block+="{}" # Add empty YAML map '{}' as placeholder value
        fi
    done
else
    # Simple case: only one non-project format, no special HTML options
    format_yaml_block="format: ${selected_formats[0]}"
fi


# --- Create Project Files ---
if [[ $is_project -eq 1 ]]; then
    # --- Create _quarto.yml for projects ---
    # (This part remains the same as it's just generated YAML)
    output_dir_name="_$( [[ "$project_type" == "book" ]] && echo "book" || echo "site" )"
    quarto_yml_content="project:\n"
    quarto_yml_content+="  type: $project_type\n"
    quarto_yml_content+="  output-dir: $output_dir_name\n"
    # Optional: Add website/book specific structure here if uncommented previously
    if [[ -n "$format_yaml_block" ]]; then
        quarto_yml_content+="\n$(echo -e "$format_yaml_block")\n"
    fi
    quarto_yml_content+="\neditor: source\n"
    echo -e "$quarto_yml_content" > _quarto.yml
    if [[ $? -ne 0 ]]; then echo "Error writing _quarto.yml"; exit 1; fi

    # --- Create main index.qmd for project ---
    # Use a variable to hold the static content. $project_name and $project_type are safe here.
    index_project_content="---
title: \"Welcome\"
# Format is controlled by _quarto.yml in projects
---

# Welcome to $project_name

This is the main page of your Quarto $project_type.

Add content here or link to other pages/chapters.
"
    echo -e "$index_project_content" > "$main_file_name"
    if [[ $? -ne 0 ]]; then echo "Error writing project index.qmd"; exit 1; fi

    # Optional: Create other starter files (about.qmd, intro.qmd) if needed

else
    # --- Create single main Qmd file ---
    # Build the YAML part, allowing shell expansion for variables and the format block
    yaml_part="---
title: \"$project_name\"
$(echo -e "$format_yaml_block")
editor: visual
execute:
  freeze: auto
---"

    # Define the body part as a literal string. Backticks are fine here.
    # Use double quotes, $ requires escaping IF it's meant literally for the shell,
    # but here knitr::opts_chunk$set is fine as $ isn't special at the end of a word usually.
    # Let's escape it just to be safe, using \$.
    body_part="# Header 1

Welcome to your new Quarto document!

\`\`\`{r setup, include=FALSE}
knitr::opts_chunk\$set(echo = TRUE, warning = FALSE, message = FALSE)
library(tidyverse)
library(davR)
library(sf)
library(jsonlite)
library(jsonlite)
\`\`\`

Start writing your content here.
"
    # --- START DEBUGGING BLOCK ---
    echo "----- DEBUG INFO -----"
    echo "Current Directory: $(pwd)"
    echo "Project Name: '$project_name'" # Added quotes for clarity
    echo "Is Project?: $is_project"
    echo "Main File Name: '$main_file_name'"
    echo "YAML part:"
    echo "$yaml_part"
    echo "Body part:"
    echo "$body_part"
    echo "Attempting to write file '$main_file_name'..."
    ls -ld . # Show permissions of the current directory
    echo "----------------------"
    # --- END DEBUGGING BLOCK ---

    # Combine the YAML part and the body part, separated by two newlines, and write to file
    echo -e "${yaml_part}\n\n${body_part}" > "$main_file_name"
    write_status=$? # Capture exit status immediately
    if [[ $write_status -ne 0 ]]; then
         echo "----- DEBUG INFO - ERROR -----"
         echo "Write command exit status: $write_status"
         echo "Error writing single document '$main_file_name'";
         echo "Maybe check permissions or if the path is valid?"
         echo "pwd is $(pwd)"
         ls -l # List files in current directory
         echo "-----------------------------"
         exit 1;
    fi
    # --- Success Message for Debugging ---
    echo "----- DEBUG INFO - SUCCESS -----"
    echo "Successfully wrote '$main_file_name' (Exit Status: $write_status)"
    ls -l "$main_file_name" # Show the created file details
    echo "-----------------------------"

fi # End of the else block for single document


# --- Optional: Create Custom CSS File ---
if [[ -n "$html_css_path" ]]; then
    # Check if the path contains directories and create them if needed
    css_dir=$(dirname "$html_css_path")
    if [[ "$css_dir" != "." ]] && [[ "$css_dir" != "$html_css_path" ]]; then
        if [[ ! -d "$css_dir" ]]; then
             echo "Creating directory for CSS: '$css_dir'"
             mkdir -p "$css_dir"
             if [[ $? -ne 0 ]]; then
                 echo "Warning: Failed to create directory '$css_dir' for CSS path '$html_css_path'."
                 # Clear the path variable so we don't attempt to write the file
                 html_css_path=""
             fi
        fi
    fi

    # Create an empty CSS file or add some default comment, only if path is still valid and dir exists
    if [[ -n "$html_css_path" ]]; then
        if [[ -d "$css_dir" ]] || [[ "$css_dir" == "." ]]; then
             if [[ ! -e "$html_css_path" ]]; then # Check if file exists before writing
                 echo "/* Custom CSS rules for $project_name */" > "$html_css_path"
                 if [[ $? -eq 0 ]]; then
                     echo "Created custom CSS file: $html_css_path"
                 else
                     echo "Warning: Failed to create custom CSS file at '$html_css_path'."
                 fi
             else
                  echo "Custom CSS file already exists: $html_css_path (skipped creation)"
             fi
        else
             echo "Warning: Directory '$css_dir' for CSS does not exist. Cannot create CSS file."
        fi
    fi
fi


# --- Final Message ---
echo ""
echo "-------------------------------------------"
echo " Successfully created Quarto structure in:"
echo "   $(pwd)" # Show the full path where it was created
echo "-------------------------------------------"
if [[ $is_project -eq 1 ]]; then
    echo " Type:        Project ($project_type)"
    echo " Config File: _quarto.yml"
    echo " Main File:   $main_file_name"
else
    echo " Type:        Single Document"
    echo " Main File:   $main_file_name"
fi

# Check if the CSS file actually exists before mentioning it
if [[ -n "$html_css_path" ]] && [[ -f "$html_css_path" ]]; then
    echo " Custom CSS:  $html_css_path (created/exists)"
fi
echo ""
echo "Next Steps:"
echo " 1. Edit the file(s) above."
echo " 2. Run 'quarto preview' or 'quarto render' inside the '$project_name' directory."
echo "-------------------------------------------"

exit 0
