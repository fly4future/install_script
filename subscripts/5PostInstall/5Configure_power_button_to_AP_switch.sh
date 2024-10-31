#!/bin/bash

# Variables
ACPI_DIR="/etc/acpi"
EVENTS_DIR="/etc/acpi/events"
SCRIPT_NAME="power_button_handler.sh"
EVENT_FILE="power_button"
AP_FILE="setup_ap.sh"
KILL_AP_FILE="kill_ap.sh"
CONF_NETPLAN_AP_DOWN_FILE="configure_netplan_and_kill_ap.sh"
SERVICE_FILE="ap_startup.service"
SRC_DIR="ap_utilities"  # Directory of the useful scripts for the AP
LOGIND_CONF="/etc/systemd/logind.conf"
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

# Ensure the ACPI events directory exists
if [ ! -d "$EVENTS_DIR" ]; then
  echo "Creating directory $EVENTS_DIR"
  sudo mkdir -p "$EVENTS_DIR"
fi

# Copy the power button script to the ACPI directory
echo "Copying $SRC_DIR/$SCRIPT_NAME to $ACPI_DIR"
sudo cp "$SRC_DIR/$SCRIPT_NAME" "$ACPI_DIR/"
sudo chmod +x "$ACPI_DIR/$SCRIPT_NAME"

# Copy the event configuration file to the ACPI events directory
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

# Copy the configure_netplan_and_kill_ap script to the bin directory
echo "Copying $SRC_DIR/$CONF_NETPLAN_AP_DOWN_FILE to $BIN_DIR"
sudo cp "$SRC_DIR/$CONF_NETPLAN_AP_DOWN_FILE" "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/$CONF_NETPLAN_AP_DOWN_FILE"

# Copy the systemd service file to the system directory
echo "Copying $SRC_DIR/$SERVICE_FILE to $SERVICE_DIR"
sudo cp "$SRC_DIR/$SERVICE_FILE" "$SERVICE_DIR/"
sudo chmod 644 "$SERVICE_DIR/$SERVICE_FILE"

# Reload systemd daemon to recognize the new service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the systemd service to ensure it runs on boot
echo "Enabling AP startup service..."
sudo systemctl enable "$SERVICE_FILE"

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
echo "Restarting acpid service..."
sudo systemctl restart acpid

# Check if GNOME is running and act accordingly
# (systemctl restart systemd-logind logs you out and disables keyboard and mouse when GNOME is running, so avoid it)
if [ -n "$DESKTOP_SESSION" ]; then
  echo "A graphical session is running."
  gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
  pkill -HUP gnome-settings-daemon
  echo "Logging out from the current graphical session."
  gnome-session-quit --logout --no-prompt
else
  echo "GNOME is not running. Restarting systemd-logind."
  sudo systemctl restart systemd-logind
fi

exit 0
