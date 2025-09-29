#!/bin/bash
# Smart Git Add - Intercepts git add to handle large files automatically
# Detects files >90MB, asks for confirmation, then moves them to iCloud and adds to .gitignore
# Remaining files are added to git normally
# Usage: This script should be aliased to override 'git add'
#
# To set up the alias, add this function to your ~/.zshrc file:
# git() {
#     if [[ $1 == "add" ]]; then
#         shift
#         "/Users/rk/projects/personal/dav/davR/helper_scripts/dav_smart_git_add.sh" "$@"
#     else
#         command git "$@"
#     fi
# }

# Source common DAV functions
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/../common/dav_common.sh" || { echo "Config failed"; return 1; }

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository. Please run this from a git repository."
    return 1
fi

# Get project information for iCloud path
get_project_info() {
    local repo_root
    local project_name
    local current_date
    local year
    local month
    
    # Get repository root and extract project name
    repo_root=$(git rev-parse --show-toplevel)
    project_name=$(basename "$repo_root")
    
    # Get current date
    current_date=$(date)
    year=$(date +%Y)
    month=$(date +%m)
    
    echo "$year" "$month" "$project_name"
}

# Create iCloud directory path
create_icloud_path() {
    local year="$1"
    local month="$2"
    local project_name="$3"
    
    local icloud_base="/Users/rk/Library/Mobile Documents/com~apple~CloudDocs/projects"
    local project_dir="${year}_${month}_${project_name}"
    local full_path="$icloud_base/$project_dir"
    
    # Create directory if it doesn't exist
    if [ ! -d "$full_path" ]; then
        mkdir -p "$full_path"
        echo "📁 Created iCloud directory: $project_dir"
    fi
    
    echo "$full_path"
}

# Check file size and move large files
process_large_files() {
    local files_to_add=("$@")
    local large_files=()
    local normal_files=()
    local files_to_move=()
    local icloud_path
    local project_info
    
    # Get project info for iCloud path
    read -r year month project_name <<< "$(get_project_info)"
    icloud_path=$(create_icloud_path "$year" "$month" "$project_name")
    
    echo "🔍 Checking file sizes before adding to git..."
    echo
    
    # If no specific files provided, check all files that would be added
    if [ ${#files_to_add[@]} -eq 0 ] || [[ "${files_to_add[0]}" == "." ]] || [[ "${files_to_add[0]}" == "-A" ]] || [[ "${files_to_add[0]}" == "--all" ]]; then
        echo "📋 Scanning all modified/untracked files..."
        # Get all files that would be added
        # Use while read loop instead of mapfile for bash 3.2 compatibility
        files_to_check=()
        while IFS= read -r file; do
            files_to_check+=("$file")
        done < <(git status --porcelain | grep -E '^(\?\?|A |M | M)' | cut -c4-)
    else
        files_to_check=("${files_to_add[@]}")
    fi
    
    # Check each file
    for file in "${files_to_check[@]}"; do
        # Skip if file/directory doesn't exist
        if [ ! -f "$file" ] && [ ! -d "$file" ]; then
            continue
        fi
        
        # If it's a directory, add it directly to normal_files (no size check needed)
        if [ -d "$file" ]; then
            normal_files+=("$file")
            continue
        fi
        
        # Get file size
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            size=$(stat -f%z "$file" 2>/dev/null)
        else
            # Linux
            size=$(stat -c%s "$file" 2>/dev/null)
        fi
        
        # Check if file is larger than 90MB (94371840 bytes)
        if [ "$size" -gt 94371840 ]; then
            large_files+=("$file")
            size_mb=$((size / 1024 / 1024))
            echo "📦 Large file detected: $file (${size_mb}MB)"
        else
            normal_files+=("$file")
        fi
    done
    
    # Handle large files
    if [ ${#large_files[@]} -gt 0 ]; then
        echo
        echo "🚨 Found ${#large_files[@]} file(s) larger than 90MB:"
        
        # Display files with sizes
        for file in "${large_files[@]}"; do
            size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            size_mb=$((size / 1024 / 1024))
            echo "   📄 $file (${size_mb}MB)"
        done
        
        echo
        
        # Ask for confirmation before moving files to iCloud
        echo "❓ Do you want to move these files to iCloud and add them to .gitignore? (y/N)"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "✅ Moving all large files to iCloud..."
            files_to_move=("${large_files[@]}")
        else
            echo "ℹ️  Skipping iCloud move. Large files will be added to git anyway."
        fi
        
        # Move selected files
        if [ ${#files_to_move[@]} -gt 0 ]; then
            echo
            echo "🔄 Moving ${#files_to_move[@]} file(s) to iCloud..."
            
            for file in "${files_to_move[@]}"; do
                # Create subdirectory structure in iCloud if needed
                file_dir=$(dirname "$file")
                if [ "$file_dir" != "." ]; then
                    mkdir -p "$icloud_path/$file_dir"
                fi
                
                # Move file to iCloud
                if mv "$file" "$icloud_path/$file"; then
                    echo "   ✅ Moved: $file → iCloud/${year}_${month}_${project_name}/$file"
                    
                    # Add to .gitignore if not already there
                    if ! grep -Fxq "$file" .gitignore 2>/dev/null; then
                        echo "$file" >> .gitignore
                        echo "   📝 Added to .gitignore: $file"
                    fi
                else
                    echo "   ❌ Failed to move: $file"
                fi
            done
            
            echo
            echo "☁️  Large files are now safely stored in iCloud at:"
            echo "   $icloud_path"
            echo
        fi
        
        # Update normal_files to include large files that weren't moved
        local remaining_large_files=()
        for file in "${large_files[@]}"; do
            local moved=false
            for moved_file in "${files_to_move[@]}"; do
                if [ "$file" = "$moved_file" ]; then
                    moved=true
                    break
                fi
            done
            if [ "$moved" = false ] && [ -f "$file" ]; then
                remaining_large_files+=("$file")
            fi
        done
        
        if [ ${#remaining_large_files[@]} -gt 0 ]; then
            echo "⚠️  ${#remaining_large_files[@]} large file(s) not moved - adding to git anyway:"
            for file in "${remaining_large_files[@]}"; do
                echo "   📄 $file"
                normal_files+=("$file")
            done
            echo
        fi
    fi
    
    # Add normal files to git
    if [ ${#normal_files[@]} -gt 0 ]; then
        echo "📝 Adding ${#normal_files[@]} file(s) to git..."
        for file in "${normal_files[@]}"; do
            echo "   ✅ Adding: $file"
        done
        
        # Actually add the files to git
        git add "${normal_files[@]}"
        echo
        echo "✅ Successfully added files to git staging area."
    else
        echo "ℹ️  No files under 90MB to add to git."
    fi
    
    # Add .gitignore if it was modified
    if [ ${#large_files[@]} -gt 0 ] && [ -f .gitignore ]; then
        git add .gitignore
        echo "📝 Added updated .gitignore to staging area."
    fi
    
    echo
    echo "📊 Summary:"
    echo "   • Files moved to iCloud: ${#files_to_move[@]}"
    echo "   • Files added to git: ${#normal_files[@]}"
    if [ ${#files_to_move[@]} -gt 0 ]; then
        echo "   • iCloud location: ${year}_${month}_${project_name}"
    fi
}

# Main execution
echo "🎯 Smart Git Add - Handling large files automatically"
echo "=================================================="

# Pass all arguments to the file processor
process_large_files "$@"

echo
echo "🎉 Smart git add completed!"
echo
echo "💡 Tip: Large files are safely stored in iCloud and can be accessed at:"
echo "   /Users/rk/Library/Mobile Documents/com~apple~CloudDocs/projects/"
