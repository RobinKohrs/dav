#!/usr/bin/env bash

# Script to scaffold a Quarto project or single document with interactive prompts.
# Uses fzf for selection menus.

# --- Configuration ---
declare -a formats=("html" "pdf" "docx" "revealjs" "website" "book" "beamer")

# --- Helper Functions ---
function check_dependency {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Required command '$1' not found." >&2
        echo "Please install it." >&2
        if [[ "$1" == "fzf" ]]; then
            echo "  macOS: brew install fzf" >&2
            echo "  Debian/Ubuntu: sudo apt install fzf" >&2
            echo "  Fedora: sudo dnf install fzf" >&2
        elif [[ "$1" == "quarto" ]]; then
            echo "  Download from https://quarto.org/docs/get-started/" >&2
        fi
        exit 1
    fi
}

# Corrected is_format_selected
function is_format_selected {
    local format_to_check="$1"
    shift # Remove the first argument (format_to_check)
    local selected_item
    for selected_item in "$@"; do # Iterate over the remaining arguments (array elements)
        if [[ "$selected_item" == "$format_to_check" ]]; then
            return 0 # Found
        fi
    done
    return 1 # Not found
}


# --- Check Dependencies ---
check_dependency "fzf"
check_dependency "quarto"

# --- Get User Input ---
echo "Quarto Project Scaffolder"
echo "-------------------------"

read -p "Enter the name for your new Quarto project/document folder: " project_name
if [[ -z "$project_name" ]]; then
    echo "Error: Project name cannot be empty." >&2
    exit 1
fi

if [[ -d "$project_name" ]]; then
    read -p "Warning: Directory '$project_name' already exists. Overwrite? (y/N): " overwrite_confirm
    if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    else
        echo "Overwriting existing directory '$project_name'..."
        rm -rf "$project_name"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to remove existing directory '$project_name'." >&2
            exit 1
        fi
    fi
fi

fzf_height=$((${#formats[@]} + 4))
echo "Select output format(s) (use Arrow Keys, TAB/Shift+TAB to select, Enter to confirm):"
selected_formats=()
while IFS= read -r line; do
    [[ -n "$line" ]] && selected_formats+=("$line")
done < <(printf "%s\n" "${formats[@]}" | fzf --prompt="Format(s): " --height="$fzf_height" --border --cycle --multi)

fzf_exit_status=$?
if [[ $fzf_exit_status -eq 130 ]]; then
    echo "Operation cancelled by user (fzf)."
    exit 1
elif [[ $fzf_exit_status -ne 0 ]]; then
    echo "Error running fzf (Exit status: $fzf_exit_status)." >&2
    exit 1
elif [[ ${#selected_formats[@]} -eq 0 ]]; then
    echo "Operation cancelled. No formats selected."
    exit 1
fi
echo "Selected format(s): ${selected_formats[*]}"


# --- HTML Specific Questions ---
html_css_path=""
html_options_yaml=""

# Pass the array elements to is_format_selected
if is_format_selected "html" "${selected_formats[@]}"; then
    echo "--- HTML Options ---"
    declare -a html_options_yaml_lines=()

    html_options_yaml_lines+=("theme: cosmo")

    read -p "Include Table of Contents (TOC) for HTML? (Y/n - default is Yes): " use_toc
    if [[ "$use_toc" =~ ^[Nn]$ ]]; then
        html_options_yaml_lines+=("toc: false")
    else
        html_options_yaml_lines+=("toc: true")
        html_options_yaml_lines+=("toc-depth: 3")
        html_options_yaml_lines+=("toc-location: left")
    fi

    html_options_yaml_lines+=("code-fold: true")
    html_options_yaml_lines+=("code-summary: \"Show Code\"")

    read -p "Use a custom CSS file for HTML? (y/N): " use_css
    if [[ "$use_css" =~ ^[Yy]$ ]]; then
        read -p "Enter path to custom CSS file (relative to '$project_name/'): " css_path_input
        if [[ -n "$css_path_input" ]]; then
            css_path_input=$(echo "$css_path_input" | sed -e 's/^"//' -e 's/"$//')
            html_css_path="$css_path_input"
            html_options_yaml_lines+=("css: $css_path_input")
        else
            echo "No CSS path provided, skipping custom CSS."
        fi
    fi

    # --- DEBUGGING BLOCK FOR HTML OPTIONS ---
    echo ""
    echo "---vvv DEBUG HTML OPTIONS vvv---"
    echo "Content of 'html_options_yaml_lines' array:"
    for i in "${!html_options_yaml_lines[@]}"; do
        printf "  [%s] = %s\n" "$i" "${html_options_yaml_lines[$i]}"
    done
    echo "---"
    # --- END DEBUGGING BLOCK ---

    if [[ ${#html_options_yaml_lines[@]} -gt 0 ]]; then
        html_options_yaml=$(printf "%s\n" "${html_options_yaml_lines[@]}")
        html_options_yaml="${html_options_yaml%\\n}"
    fi

    # --- DEBUGGING BLOCK FOR HTML OPTIONS STRING ---
    echo "Resulting 'html_options_yaml' string (to be indented):"
    echo "-----BEGIN HTML_OPTIONS_YAML-----"
    echo -e "${html_options_yaml}" # Use -e to interpret potential newlines correctly for display
    echo "-----END HTML_OPTIONS_YAML-----"
    echo "---^^^ DEBUG HTML OPTIONS ^^^---"
    echo ""
    # --- END DEBUGGING BLOCK ---
fi


# --- Create Project Structure ---
echo ""
echo "Creating project structure in '$project_name'..."
mkdir -p "$project_name"
if [[ $? -ne 0 ]]; then echo "Error: Failed to create directory '$project_name'." >&2; exit 1; fi
cd "$project_name" || { echo "Error: Failed to cd into '$project_name'." >&2; exit 1; }


# --- Generate YAML ---
main_file_name="index.qmd"
project_type=""
is_project=0

# Corrected calls to is_format_selected
if is_format_selected "website" "${selected_formats[@]}" || is_format_selected "book" "${selected_formats[@]}"; then
    is_project=1
    if is_format_selected "book" "${selected_formats[@]}"; then
        project_type="book"
    elif is_format_selected "website" "${selected_formats[@]}"; then
        project_type="website"
    fi
fi


# --- Build the format YAML block ---
format_yaml_block=""
if [[ ${#selected_formats[@]} -gt 1 ]] || [[ $is_project -eq 1 ]] || [[ -n "$html_options_yaml" ]]; then
    format_yaml_block="format:"
    for fmt_item in "${selected_formats[@]}"; do
        if [[ ("$fmt_item" == "website" && "$project_type" == "website") || \
              ("$fmt_item" == "book" && "$project_type" == "book") ]]; then
            continue
        fi

        format_yaml_block+="\n  $fmt_item:"
        sub_options_added=0
        current_format_options=""

        if [[ "$fmt_item" == "html" ]] && [[ -n "$html_options_yaml" ]]; then
            current_format_options+="\n$(echo -e "${html_options_yaml}" | sed 's/^/    /')"
            sub_options_added=1
        elif [[ "$fmt_item" == "pdf" ]]; then
            current_format_options+="\n    documentclass: article"
            current_format_options+="\n    toc: true"
            sub_options_added=1
        fi

        if [[ $sub_options_added -eq 0 ]]; then
            format_yaml_block+="{}"
        else
            format_yaml_block+="$current_format_options"
        fi
    done
else
    if [[ ${#selected_formats[@]} -eq 1 ]]; then
        format_yaml_block="format: ${selected_formats[0]}"
    else
        format_yaml_block="format: html # Fallback"
    fi
fi


# --- Create Project Files ---
if [[ $is_project -eq 1 ]]; then
    output_dir_name="_$( [[ "$project_type" == "book" ]] && echo "book" || echo "site" )"
    quarto_yml_content="project:\n"
    quarto_yml_content+="  type: $project_type\n"
    quarto_yml_content+="  output-dir: $output_dir_name\n"

    if [[ -n "$format_yaml_block" ]]; then
         quarto_yml_content+="\n${format_yaml_block}\n"
    fi

    quarto_yml_content+="\neditor: source\n"
    quarto_yml_content+="execute:\n"
    quarto_yml_content+="  echo: true\n"
    quarto_yml_content+="  warning: false\n"
    quarto_yml_content+="  message: false\n"
    quarto_yml_content+="  freeze: auto\n"

    echo -e "$quarto_yml_content" > _quarto.yml
    if [[ $? -ne 0 ]]; then echo "Error writing _quarto.yml" >&2; exit 1; fi

    index_project_content="---
title: \"Welcome\"
---

# Welcome to $project_name

This is the main page of your Quarto $project_type.
"
    echo -e "$index_project_content" > "$main_file_name"
    if [[ $? -ne 0 ]]; then echo "Error writing project $main_file_name" >&2; exit 1; fi
else
    # Single document
    yaml_part="---
title: \"$project_name\"
$(echo -e "$format_yaml_block")
editor: source
execute:
  echo: true
  warning: false
  message: false
  freeze: auto
---"

    body_part="# Header 1

Welcome to your new Quarto document!

\`\`\`{r setup, include=FALSE}
knitr::opts_chunk\$set(echo = TRUE, warning = FALSE, message = FALSE)
library(tidyverse)
# library(davR)
# library(sf)
# library(jsonlite)
\`\`\`

Start writing your content here.
"
    echo -e "${yaml_part}\n\n${body_part}" > "$main_file_name"
    write_status=$?
    if [[ $write_status -ne 0 ]]; then
         echo "Error writing single document '$main_file_name' (status: $write_status)." >&2
         exit 1;
    fi
fi

# --- Optional: Create Custom CSS File ---
if [[ -n "$html_css_path" ]]; then
    css_dir=$(dirname "$html_css_path")
    if [[ "$css_dir" != "." ]] && [[ "$css_dir" != "$html_css_path" ]]; then
        if [[ ! -d "$css_dir" ]]; then
             echo "Creating directory for CSS: '$css_dir'"
             mkdir -p "$css_dir"
             if [[ $? -ne 0 ]]; then
                 echo "Warning: Failed to create directory '$css_dir' for CSS path '$html_css_path'." >&2
                 html_css_path=""
             fi
        fi
    fi

    if [[ -n "$html_css_path" ]]; then
        target_dir_for_css=$([[ "$css_dir" == "." ]] && echo "." || echo "$css_dir")
        if [[ -d "$target_dir_for_css" ]]; then
             if [[ ! -e "$html_css_path" ]]; then
                 echo "/* Custom CSS rules for $project_name */" > "$html_css_path"
                 if [[ $? -eq 0 ]]; then
                     echo "Created custom CSS file: $html_css_path"
                 else
                     echo "Warning: Failed to create custom CSS file at '$html_css_path'." >&2
                 fi
             else
                  echo "Custom CSS file already exists: $html_css_path (skipped creation)"
             fi
        else
             echo "Warning: Directory '$target_dir_for_css' for CSS does not exist. Cannot create CSS file." >&2
        fi
    fi
fi

# --- Final Message ---
echo ""
echo "-------------------------------------------"
echo " Successfully created Quarto structure in:"
echo "   $(pwd)"
echo "-------------------------------------------"
if [[ $is_project -eq 1 ]]; then
    echo " Type:        Project ($project_type)"
    echo " Config File: _quarto.yml"
    echo " Main File:   $main_file_name"
else
    echo " Type:        Single Document"
    echo " Main File:   $main_file_name"
fi

if [[ -n "$html_css_path" ]] && [[ -f "$html_css_path" ]]; then
    echo " Custom CSS:  $html_css_path (created/exists)"
fi
echo ""
echo "Next Steps:"
echo " 1. Edit the file(s) above."
echo " 2. Run 'quarto preview' or 'quarto render' inside the '$project_name' directory."
echo "-------------------------------------------"

exit 0
