#!/bin/bash

set -euo pipefail

script_dir="$(dirname "$(realpath "$0")")"

destination="/var/lib/AccountsService/icons/$USER"

user_file="/var/lib/AccountsService/users/$USER"

sudo mkdir -p "$(dirname "$destination")" "$(dirname "$user_file")"
sudo cp "$script_dir/DISREGARD/profile.png" "$destination"

# Ensure the profile picture for GNOME is pointed to the correct location
if [ ! -f "$user_file" ]; then
  printf '[User]\nIcon=%s\n' "$destination" | sudo tee "$user_file" >/dev/null
elif sudo grep -q "^Icon=" "$user_file"; then
  sudo sed -i "s|^Icon=.*$|Icon=$destination|" "$user_file"
else
  echo "Icon=$destination" | sudo tee -a "$user_file" >/dev/null
fi

echo "Profile picture has been set."

exit 0
