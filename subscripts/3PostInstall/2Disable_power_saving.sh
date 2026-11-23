#!/bin/bash

set -euo pipefail

script_dir="$(dirname "$(realpath "$0")")"

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
        sudo cp "$script_dir/DISREGARD/disable-wlan0-power_saving.service" /etc/systemd/system/disable-wlan0-power_saving.service
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

function disable_screen_dimming(){
    gsettings set org.gnome.desktop.session idle-delay 0
}

# Mode IDs don't follow power and differ between modules and firmwares, so the wattage is taken from the mode name
# (e.g. 25W or MODE_30W). Modes without a wattage, such as MAXN, are ignored on purpose because they have no power cap
# and can cause overheating and throttling.
function get_highest_jetson_power_mode() {
    sed -nE 's/^< *POWER_MODEL ID=([0-9]+) NAME=([^ >]+).*/\1 \2/p' /etc/nvpmodel.conf | awk '
    match($2, /[0-9]+W/) {
        watts = substr($2, RSTART, RLENGTH - 1) + 0
        if (watts > best) { best = watts; mode = $1 " " $2 }
    }
    END { print mode }'
}

function set_jetson_power_mode() {
    local mode_id mode_name
    read -r mode_id mode_name <<<"$(get_highest_jetson_power_mode)"

    if [[ -z "$mode_id" ]]; then
        echo "No power mode with a wattage found in /etc/nvpmodel.conf, leaving the Jetson power mode unchanged."
        return 0
    fi

    if [[ "$(sudo nvpmodel -q | grep -E '^[0-9]+$')" == "$mode_id" ]]; then
        echo "Jetson power mode is already set to $mode_name"
        return 0
    fi

    echo "Setting Jetson power mode to $mode_name (mode $mode_id). Reboot is required for the change to take effect."

    if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
        sudo nvpmodel --mode "$mode_id"
    else
        sudo nvpmodel --mode "$mode_id" --force
    fi
}

disable_hibernation
disable_wlan0_power_saving
disable_screen_dimming
set_power_mode

# This should be last because it will ask for reboot, which will stop the script from running any further.
if grep -q "NVIDIA Jetson" /proc/device-tree/model >/dev/null 2>&1; then
    set_jetson_power_mode
fi

exit 0
