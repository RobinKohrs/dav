#!/bin/bash
# Adds all files larger than 100MB (recursively from current directory) to .gitignore if not already present.
# Usage: bash gitignore_large_files.sh

find . -type f ! -path './.git/*' ! -name '.gitignore' -size +100M | while read -r file; do
  # Remove leading ./ for gitignore
  rel_path="${file#./}"
  # Check if already in .gitignore
  if ! grep -Fxq "$rel_path" .gitignore 2>/dev/null; then
    echo "$rel_path" >> .gitignore
    echo "Added to .gitignore: $rel_path"
  fi
done 