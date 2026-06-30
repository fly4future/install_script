#!/bin/bash

script_dir="$(dirname "$(realpath "$0")")"
folder_path="$script_dir/DISREGARD/wallpapers"

# Build options array
options=()
for file in "$folder_path"/*; do
  [ -f "$file" ] || continue
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

local_wallpaper_path="$folder_path/$wallpaper"  # The wallpaper path in the local subscripts folder
sudo mkdir -p "/usr/share/backgrounds"  # Ensure the system backgrounds folder exists
system_wallpaper_path="/usr/share/backgrounds/$wallpaper" # The wallpaper path in the system folder. Technically RPi uses a different directory for their defaults, but this one seem to be the most universal one.

# Copy the selected wallpaper to the system folder, so that it persists even after we delete the install script directory
sudo cp "$local_wallpaper_path" "$system_wallpaper_path"

gsettings set org.gnome.desktop.background picture-uri "file://$system_wallpaper_path"       # Light mode
gsettings set org.gnome.desktop.background picture-uri-dark "file://$system_wallpaper_path"  # Dark mode

# Exit 1 will not show the "Press enter to continue" menu but rather go straight back to the main menu
exit 1
