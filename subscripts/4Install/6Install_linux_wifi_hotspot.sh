#!/bin/bash

# Define the repository URL and the target directory
REPO_URL="https://github.com/lakinduakash/linux-wifi-hotspot"
TARGET_DIR="/tmp/linux-wifi-hotspot"

sudo apt install -y libgtk-3-dev build-essential gcc g++ pkg-config make hostapd libqrencode-dev libpng-dev

if [ -d "$TARGET_DIR" ]; then
    echo "Removing existing directory $TARGET_DIR"
    rm -rf "$TARGET_DIR"
fi
git clone "$REPO_URL" "$TARGET_DIR"

cd "$TARGET_DIR"
make
sudo make install-cli-only
rm -rf "$TARGET_DIR"
exit 0