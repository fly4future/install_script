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

# Copy the scripts to the bin directory
echo "Copying scripts to /usr/local/bin..."
sudo cp "$SRC_DIR/$AP_FILE" "$SRC_DIR/$KILL_AP_FILE" "$SRC_DIR/$CONF_NETPLAN_AP_DOWN_FILE" "$BIN_DIR/"
sudo chmod +x "$BIN_DIR/$AP_FILE" "$BIN_DIR/$KILL_AP_FILE" "$BIN_DIR/$CONF_NETPLAN_AP_DOWN_FILE"

# Copy the systemd service file to the system directory
echo "Copying $SRC_DIR/$SERVICE_FILE to $SERVICE_DIR"
sudo cp "$SRC_DIR/$SERVICE_FILE" "$SERVICE_DIR/"
sudo chmod 644 "$SERVICE_DIR/$SERVICE_FILE"  # Alternatively, use chmod 600 for tighter security

# Reload systemd daemon to recognize the new service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Prompt the user if they want to enable the AP mode on next boot
read -p "Do you want to enable the AP mode on the next boot of the drone? (y/n): " ENABLE_AP
if [[ "$ENABLE_AP" =~ ^[Yy]$ ]]; then
  sudo systemctl enable $SERVICE_FILE
fi

# Prompt the user if they want to use the power button to trigger AP mode
read -p "Do you want to use the power button as the trigger for AP mode? (y/n) (do not use for RoboFly): " USE_POWER_BUTTON
if [[ "$USE_POWER_BUTTON" =~ ^[Yy]$ ]]; then
  ENABLE_POWER_BUTTON=true
else
  ENABLE_POWER_BUTTON=false
fi

# Ensure the ACPI events directory exists if power button is being used
if [ "$ENABLE_POWER_BUTTON" = true ]; then
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

  # Set the logind configuration to ignore power button and not power off if the power button is used for AP mode
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

  # Handle power button behavior based on desktop session presence
  if pgrep -x "gnome-shell" > /dev/null; then
    # GNOME session detected
    echo "Detected GNOME session. Applying GNOME-specific power settings."
    gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'nothing'
    pkill -HUP gnome-settings-daemon

    if [[ "$DESKTOP_SESSION" == "i3" ]]; then
      # i3 session detected
      echo "Detected i3 session. Preparing to log out."
      LOGOUT_COMMAND="i3 exit"
    else
      LOGOUT_COMMAND="gnome-session-quit --logout --no-prompt"
    fi

    # Prompt the user to confirm logout
    read -p "Press 'y' to log out now and apply settings, or any other key to cancel this action: " USER_INPUT
    if [[ "$USER_INPUT" =~ ^[Yy]$ ]]; then
      echo "Logging out now."
      eval "$LOGOUT_COMMAND"
    else
      echo "Logout canceled. Please remember to log out manually to apply the changes."
    fi
  else
    # No graphical session detected
    echo "No graphical session detected. Restarting systemd-logind."
    sudo systemctl restart systemd-logind
  fi
fi

exit 0
