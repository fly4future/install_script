#!/bin/bash

set -euo pipefail

destination="/var/lib/AccountsService/icons/$USER"

sudo cp subscripts/6Branding/DISREGARD/profile.png "$destination"

# Ensure the profile picture for GNOME is pointed to the correct location
sudo sed -i "s|^Icon=.*$|Icon=$destination|" "/var/lib/AccountsService/users/$USER"

echo "Profile picture has been set."

exit 0
