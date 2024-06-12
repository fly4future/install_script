#!/bin/bash

# Variables
ACPI_DIR="/etc/acpi"
EVENTS_DIR="/etc/acpi/events"
SCRIPT_NAME="power_button_handler.sh"
EVENT_FILE="power_button"
AP_FILE="setup_ap.sh"
KILL_AP_FILE="kill_ap.sh"
SRC_DIR="ap_utilities"  # Change this to the directory where your script and event file are located
LOGIND_CONF="/etc/systemd/logind.conf"
BIN_DIR="/usr/local/bin"
UAV_NAME_FILE="/etc/uav_name"

# Source the user's .bashrc to inherit environment variables
source /home/uav/.bashrc

# Get the UAV_NAME variable from the environment
UAV_NAME_VALUE=$UAV_NAME

# Create the /etc/uav_name file with the UAV_NAME value
if [ -n "$UAV_NAME_VALUE" ]; then
  echo "Creating $UAV_NAME_FILE with UAV_NAME=$UAV_NAME_VALUE"
  echo "UAV_NAME=$UAV_NAME_VALUE" | sudo tee "$UAV_NAME_FILE"
else
  echo "UAV_NAME is not set in the environment. Please check your .bashrc."
fi

# Ensure the acpi events directory exists
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
sudo chmod +x "$BIN_DIR/$AP_FILE"

# Copy the kill_ap script to the bin directory
echo "Copying $SRC_DIR/$KILL_AP_FILE to $BIN_DIR"
sudo cp "$SRC_DIR/$KILL_AP_FILE" "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/$KILL_AP_FILE"

# Set the logind configuration to ignore power button and not power off 
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

# Restart the acpid service
sudo systemctl restart acpid

# Check if GNOME is running
if pgrep -x "gnome-shell" > /dev/null; then
  echo "GNOME is running. Applying GNOME-specific power settings."
  gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
  pkill -HUP gnome-settings-daemon
  echo "Logging out from the current GNOME session."
  gnome-session-quit --logout --no-prompt
else
  echo "GNOME is not running. Restarting systemd-logind."
  sudo systemctl restart systemd-logind
fi

exit 0
