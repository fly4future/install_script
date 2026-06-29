#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"
folder_path="$script_dir/DISREGARD/wallpapers"

echo "Available wallpapers in $folder_path"

# Build options array
options=()
for file in "$folder_path"/*; do
  filename=$(basename "$file")
  options+=("$filename" "")
done

wallpaper=$(whiptail \
  --title "Set Wallpaper" \
  --menu "Select wallpaper:" 0 0 0 \
  "${options[@]}" \
  3>&1 1>&2 2>&3)

# If user cancelled
if [ $? -ne 0 ]; then
  echo "Cancelled."
  exit 1
fi

# Full path to selected file
wallpaper_path="$folder_path/$wallpaper"

gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path" # Light mode
gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_path" # Dark mode

# Exit 1 will not show the "Press enter to continue" menu but rather go straight back to the main menu
exit 1
