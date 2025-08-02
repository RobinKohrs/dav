#!/bin/bash
# Comprehensive large file management for Git repositories.
# Adds untracked files larger than 90MB to .gitignore and optionally removes tracked large files from Git.
# Usage: bash gitignore_large_files.sh [--remove-tracked] [--clean-history]

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository. Please run this script from a git repository root."
    exit 1
fi

# Check if --remove-tracked flag is provided
REMOVE_TRACKED=false
CLEAN_HISTORY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-tracked)
            REMOVE_TRACKED=true
            shift
            ;;
        --clean-history)
            CLEAN_HISTORY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: bash gitignore_large_files.sh [--remove-tracked] [--clean-history]"
            exit 1
            ;;
    esac
done

echo "=== Large File Management Script ==="
echo

# First, handle tracked large files if requested
if [ "$REMOVE_TRACKED" = true ]; then
    echo "Searching for tracked files larger than 90MB..."
    
    # Get list of tracked files and check their sizes
    tracked_large_files=""
    while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
            if [ "$size" -gt 94371840 ]; then  # 90MB in bytes
                tracked_large_files="$tracked_large_files$file"$'\n'
            fi
        fi
    done < <(git ls-files -z)

    if [ -z "$tracked_large_files" ]; then
        echo "No tracked files larger than 90MB found."
    else
        echo "Found tracked files larger than 90MB:"
        echo "$tracked_large_files" | while read -r file; do
            if [ -n "$file" ]; then
                size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
                size_mb=$((size / 1024 / 1024))
                echo "  - $file (${size_mb}MB)"
            fi
        done
        echo

        echo "Removing large files from Git tracking..."
        echo "$tracked_large_files" | while read -r file; do
            if [ -n "$file" ]; then
                echo "Removing from tracking: $file"
                git rm --cached --ignore-unmatch "$file"
            fi
        done
        echo "Tracked large files have been removed from Git tracking."
        echo
    fi
fi

# Clean Git history if requested
if [ "$CLEAN_HISTORY" = true ]; then
    echo "Cleaning Git history to remove large files completely..."
    
    # Build the filter-branch command with all large files
    if [ -n "$tracked_large_files" ]; then
        filter_cmd="git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch"
        echo "$tracked_large_files" | while read -r file; do
            if [ -n "$file" ]; then
                filter_cmd="$filter_cmd \"$file\""
            fi
        done
        filter_cmd="$filter_cmd' --prune-empty --tag-name-filter cat -- --all"
        
        echo "Running: $filter_cmd"
        eval "$filter_cmd"
        echo "Git history has been cleaned."
        echo
    else
        echo "No large files found to clean from history."
    fi
fi

# Then handle untracked large files
echo "Searching for untracked files larger than 90MB..."

# Find large files and count them
large_files=$(find . -type f ! -path './.git/*' ! -name '.gitignore' -size +90M)
file_count=$(echo "$large_files" | grep -c .)

if [ "$file_count" -eq 0 ]; then
    echo "No untracked files larger than 90MB found."
    exit 0
fi

echo "Found $file_count untracked file(s) larger than 90MB:"
echo "$large_files" | while read -r file; do
    echo "  - $file"
done
echo

# Process each large file
echo "Processing untracked large files..."
echo "$large_files" | while read -r file; do
  # Remove leading ./ for gitignore
  rel_path="${file#./}"
  # Check if already in .gitignore
  if ! grep -Fxq "$rel_path" .gitignore 2>/dev/null; then
    echo "$rel_path" >> .gitignore
    echo "Added to .gitignore: $rel_path"
  else
    echo "Already in .gitignore: $rel_path"
  fi
done

echo
echo "=== Summary ==="
if [ "$REMOVE_TRACKED" = true ]; then
    echo "✓ Tracked large files have been removed from Git tracking"
    if [ "$CLEAN_HISTORY" = true ]; then
        echo "✓ Git history has been cleaned (large files completely removed)"
    fi
    echo "✓ Untracked large files have been added to .gitignore"
    echo
    echo "Next steps:"
    echo "1. Review the changes: git status"
    echo "2. Commit the changes: git commit -m 'Remove large files from tracking and update .gitignore'"
    if [ "$CLEAN_HISTORY" = true ]; then
        echo "3. Force push to remote: git push --force origin <branch>"
    else
        echo "3. Push to remote: git push origin <branch>"
    fi
else
    echo "✓ Untracked large files have been added to .gitignore"
    echo
    echo "Note: If you have tracked files larger than 90MB, run this script with:"
    echo "  bash gitignore_large_files.sh --remove-tracked"
    echo "  bash gitignore_large_files.sh --remove-tracked --clean-history"
fi 