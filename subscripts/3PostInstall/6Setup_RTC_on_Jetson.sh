#!/bin/bash

set -euo pipefail

# Check if we're running on an NVIDIA Jetson device.
if ! grep -q "NVIDIA Jetson" /proc/device-tree/model >/dev/null 2>&1; then
    echo "ERROR: This script is intended to run on NVIDIA Jetson devices only."
    exit 0
fi

# Verify hwclock command exists
if ! command -v hwclock >/dev/null 2>&1; then
    echo "ERROR: hwclock not found. Installing it..."
    apt-get update && apt-get install -y util-linux
fi

# In interactive mode we prompt the user to confirm they installed a RTC battery
if [[ "$NON_INTERACTIVE_MODE" -ne 1 ]]; then
    echo "Ensure there is a battery for the RTC installed. Press Enter to continue or Ctrl+C to abort."
    read -r
fi

echo "Writing system time to RTC..."
sudo hwclock --systohc

echo "Creating systemd services..."
sudo cp subscripts/3PostInstall/DISREGARD/set_hw_time_from_sys.service /etc/systemd/system/set_hw_time_from_sys.service
sudo cp subscripts/3PostInstall/DISREGARD/set_sys_time_from_hw.service /etc/systemd/system/set_sys_time_from_hw.service

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Starting services..."
sudo systemctl enable --now set_hw_time_from_sys.service
sudo systemctl enable --now set_sys_time_from_hw.service

echo ""
echo "RTC setup complete"
echo "On boot, the system time will be read from the RTC"
echo "Every time NTP updates the system time, it will be written back to the RTC"
echo "After flashing keep the system online for some time so that NTP can update the system time and write it to the RTC"

if [[ "$NON_INTERACTIVE_MODE" -ne 1 ]]; then
    read -p "Press Enter to continue..."
fi

exit 0
