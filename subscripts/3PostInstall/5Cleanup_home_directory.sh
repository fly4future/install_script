#!/bin/bash

set -euo pipefail

# Remove default Ubuntu folders from home directory (only if they are empty)
directories=("$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Music" "$HOME/Pictures" "$HOME/Public" "$HOME/Templates" "$HOME/Videos")
for dir in "${directories[@]}"; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
        echo "Removing empty directory: $dir"
        rmdir "$dir"
    else
        echo "Skipping $dir (not empty)"
    fi
done

if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
    read -p "Press Enter to continue..."
fi

exit 0
