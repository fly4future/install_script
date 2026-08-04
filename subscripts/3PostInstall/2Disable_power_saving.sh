#!/bin/bash

set -euo pipefail

function disable_hibernation() {
    echo "Disabling hibernation"
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    echo "Hibernation disabled"
}

function disable_wlan0_power_saving() {
    # Check if an interface "wlan0" exists, if it doesn't the computer either doesn't have a WiFi card or "Predictable Network Interface Names" feature is enabled, meaning
    # the user hasn't ran the "Fix network interface names" script yet.

    if ! ip link show wlan0 &> /dev/null; then
        echo "No wlan0 interface found. You probably forgot to run the 'Fix network interface names' script first."
    else
        echo "Disabling power saving mode on wlan0 interface"

        # Check if the "iw" command is available, if not install it.
        if ! command -v iw &>/dev/null; then
            echo "iw command not found. Installing it."
            sudo apt-get install -y iw
        fi

        # Disable power saving mode on wlan0 interface.
        sudo iw wlan0 set power_save off

        # The setting does not persist across reboots, so we also create a systemd service to disable it on boot.
        sudo cp subscripts/3PostInstall/DISREGARD/disable-wlan0-power_saving.service /etc/systemd/system/disable-wlan0-power_saving.service
        sudo systemctl daemon-reload
        sudo systemctl enable --now disable-wlan0-power_saving.service

        echo "Power saving mode on wlan0 interface disabled"
    fi
}

function set_power_mode() {

    # Most times the power modes available are "performance", "balanced" and "power-saver",
    # but sometimes some are missing (for example on Jetsons only power-saver" and "balanced" are available)
    # For this reason we check which modes are available and set the highest one available.
    if powerprofilesctl list | grep -q "performance"; then
        echo "Setting power mode to performance"
        sudo powerprofilesctl set performance
    elif powerprofilesctl list | grep -q "balanced"; then
        echo "Setting power mode to balanced"
        sudo powerprofilesctl set balanced
    else
        echo "Power mode names on this system are unrecognized. Run 'powerprofilesctl list' to check which power modes are available and report this to the install script developer."
        exit 1
    fi
}

function set_jetson_power_mode() {
    echo "Setting Jetson power mode to 25W. Reboot is required for the change to take effect."
    sudo nvpmodel --mode 3
}

disable_hibernation
disable_wlan0_power_saving
set_power_mode

# This should be last because it will ask for reboot, which will stop the script from running any further.
if grep -q "NVIDIA Jetson" /proc/device-tree/model >/dev/null 2>&1; then
    set_jetson_power_mode
fi

exit 0
