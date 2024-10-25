#!/bin/bash

# Define the repository URL and the target directory
REPO_URL="https://github.com/lakinduakash/linux-wifi-hotspot"
TARGET_DIR="/tmp/linux-wifi-hotspot"

# Update package list and install necessary dependencies
sudo apt-get update
sudo apt-get install -y libgtk-3-dev build-essential gcc g++ pkg-config make hostapd libqrencode-dev libpng-dev haveged python3-pip

# Install yq using pip
sudo pip3 install yq

# Install haveged to avoid low entropy issues (will be started only when needed)
if ! systemctl is-active --quiet haveged; then
    sudo systemctl enable haveged
fi

# Clone the repository and install the tool
if [ -d "$TARGET_DIR" ]; then
    sudo rm -rf "$TARGET_DIR"
fi
sudo git clone "$REPO_URL" "$TARGET_DIR"

# Build and install CLI-only version
cd "$TARGET_DIR"
sudo make && sudo make install-cli-only

# Clean up target directory if installation succeeds
sudo rm -rf "$TARGET_DIR"

exit 0
