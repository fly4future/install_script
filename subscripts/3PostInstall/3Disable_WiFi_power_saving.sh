#!/bin/bash

# Check if an interface "wlan0" exists, if it doesn't the computer either doesn't have a WiFi card or "Predictable Network Interface Names" feature is enabled, meaning
# the user hasn't ran the "Fix network interface names" script yet.

if ! ip link show wlan0 &> /dev/null; then
  echo "No wlan0 interface found. You probably forgot to run the 'Fix network interface names' script first."
  exit 0
fi

echo "Disabling power saving mode on wlan0 interface"

# Disable power saving mode on wlan0 interface.
sudo iw wlan0 set power_save off

# The setting does not persist across reboots, so we also create a systemd service to disable it on boot.
sudo cp subscripts/3PostInstall/DISREGARD/disable-wlan0-power_saving.service /etc/systemd/system/disable-wlan0-power_saving.service
sudo systemctl daemon-reload
sudo systemctl enable --now disable-wlan0-power_saving.service

echo "Power saving mode on wlan0 interface disabled"
exit 0
