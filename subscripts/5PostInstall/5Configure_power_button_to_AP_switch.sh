#!/bin/bash

# Variables
ACPI_DIR="/etc/acpi"
EVENTS_DIR="/etc/acpi/events"
SCRIPT_NAME="power_button_handler.sh"
EVENT_FILE="power_button"
AP_FILE="setup_ap.sh"
SRC_DIR="ap_utilities"  
LOGIND_CONF="/etc/systemd/logind.conf"
BIN_DIR="/usr/local/bin"

# Ensure the events directory exists
if [ ! -d "$EVENTS_DIR" ]; then
  echo "Creating directory $EVENTS_DIR"
  sudo mkdir -p "$EVENTS_DIR"
fi

# Copy the power button script to the acpi directory
echo "Copying $SRC_DIR/$SCRIPT_NAME to $ACPI_DIR"
sudo cp "$SRC_DIR/$SCRIPT_NAME" "$ACPI_DIR/"
sudo chmod +x "$ACPI_DIR/$SCRIPT_NAME"

# Copy the event configuration file to the acpi events directory
echo "Copying $SRC_DIR/$EVENT_FILE to $EVENTS_DIR"
sudo cp "$SRC_DIR/$EVENT_FILE" "$EVENTS_DIR/"

# Copy the setup_ap script to the bin directory
echo "Copying $SRC_DIR/$AP_FILE to $BIN_DIR"
sudo cp "$SRC_DIR/$AP_FILE" "$BIN_DIR/"

# Set the logind configuration to ignore power button and not poweroff 
if grep -q "^#HandlePowerKey=" "$LOGIND_CONF"; then
  echo "Uncommenting and updating HandlePowerKey setting in $LOGIND_CONF"
  sudo sed -i 's/^#HandlePowerKey=.*/HandlePowerKey=ignore/' "$LOGIND_CONF"
elif grep -q "^HandlePowerKey=" "$LOGIND_CONF"; then
  echo "Updating HandlePowerKey setting in $LOGIND_CONF"
  sudo sed -i 's/^HandlePowerKey=.*/HandlePowerKey=ignore/' "$LOGIND_CONF"
else
  echo "Adding HandlePowerKey setting to $LOGIND_CONF"
  echo "HandlePowerKey=ignore" | sudo tee -a "$LOGIND_CONF"
fi

# Restart the systemd-logind service
echo "Restarting systemd-logind service"
sudo systemctl restart systemd-logind

# Restart the acpid service
echo "Restarting acpid service"
sudo systemctl restart acpid
exit 0
