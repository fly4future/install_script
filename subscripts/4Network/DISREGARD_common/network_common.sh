#!/bin/bash

# Functions shared by the network scripts.
# Switching the network configuration can cut the connection to the device (for example SSH over Wi-Fi),
# so every change is applied together with an automatic revert that runs unless the user confirms the new configuration.

NETPLAN_DIR="/etc/netplan"
REVERT_UNIT="install-script-network-revert"
REVERT_TIMEOUT=120

use_systemd_networkd() {
  sudo systemctl unmask systemd-networkd.socket systemd-networkd systemd-resolved
  sudo systemctl enable --now systemd-networkd systemd-resolved
  sudo systemctl disable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher 2>/dev/null || true
  sudo systemctl mask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher 2>/dev/null || true
}

use_network_manager() {
  sudo systemctl unmask NetworkManager NetworkManager-wait-online NetworkManager-dispatcher systemd-resolved
  sudo systemctl enable --now NetworkManager NetworkManager-wait-online NetworkManager-dispatcher systemd-resolved
  sudo systemctl disable --now systemd-networkd.socket systemd-networkd 2>/dev/null || true
  sudo systemctl mask systemd-networkd.socket systemd-networkd
}

# netplan does not clean up after a networkd config. The leftover udev rules mark the interfaces as unmanaged by NetworkManager
# and the netplan wpa_supplicant keeps running, so remove them and let NetworkManager pick up the interfaces.
# Has to be called after "netplan apply".
hand_over_to_network_manager() {
  sudo rm -f /run/udev/rules.d/90-netplan.rules
  sudo systemctl stop 'netplan-wpa-*.service'
  sudo udevadm control --reload
  sudo udevadm trigger --action=change --subsystem-match=net
  sudo udevadm settle
  sudo systemctl restart NetworkManager
}

# Renames a netplan config to *.yaml.bak, so that netplan ignores it. Existing backups are not overwritten.
disable_netplan_config() {
  local file="$1"
  local backup="$file.bak"

  if sudo test -e "$backup"; then
    backup="$file.bak.$(date +%Y%m%d_%H%M%S)"
  fi

  sudo mv -- "$file" "$backup"
  echo "Disabled $file (renamed to $backup)"
}

# Saves the current netplan configs and the active renderer, and creates a script that restores them
prepare_revert() {
  local previous_renderer="networkd"
  if systemctl is-active --quiet NetworkManager; then
    previous_renderer="NetworkManager"
  fi

  # Remove leftovers from a previous run that was interrupted or confirmed from another session
  sudo systemctl stop "$REVERT_UNIT.timer" 2>/dev/null || true
  sudo systemctl reset-failed "$REVERT_UNIT.service" "$REVERT_UNIT.timer" 2>/dev/null || true
  sudo rm -rf /var/tmp/network-revert.*

  REVERT_DIR=$(sudo mktemp -d /var/tmp/network-revert.XXXXXX)
  sudo mkdir "$REVERT_DIR/netplan"
  sudo cp -a "$NETPLAN_DIR"/. "$REVERT_DIR/netplan/"

  {
    echo "#!/bin/bash"
    echo "# Restores the network configuration from before the network scripts made changes"
    declare -f use_systemd_networkd use_network_manager hand_over_to_network_manager
    echo "find $NETPLAN_DIR -maxdepth 1 -type f -delete"
    echo "cp -a $REVERT_DIR/netplan/. $NETPLAN_DIR/"
    if [ "$previous_renderer" = "NetworkManager" ]; then
      echo "use_network_manager"
      echo "netplan apply"
      echo "hand_over_to_network_manager"
    else
      echo "use_systemd_networkd"
      echo "netplan apply"
    fi
    echo "rm -rf $REVERT_DIR"
  } | sudo tee "$REVERT_DIR/revert.sh" >/dev/null
}

# Restores only the netplan files, used when the new config failed before any service was changed
restore_netplan_files() {
  sudo find "$NETPLAN_DIR" -maxdepth 1 -type f -delete
  sudo cp -a "$REVERT_DIR/netplan/." "$NETPLAN_DIR/"
  sudo netplan generate
  sudo rm -rf "$REVERT_DIR"
}

# Starts a timer that reverts the network configuration unless it is stopped by confirm_or_revert.
# It runs as a systemd timer so that the revert also happens when this script is killed by a dropped SSH connection.
schedule_revert() {
  sudo systemd-run --quiet --unit="$REVERT_UNIT" --on-active="${REVERT_TIMEOUT}s" /bin/bash "$REVERT_DIR/revert.sh"
}

revert_now() {
  echo "Reverting to the previous network configuration ..."
  sudo systemctl stop "$REVERT_UNIT.timer" 2>/dev/null || true
  sudo bash "$REVERT_DIR/revert.sh"
  echo "Previous network configuration restored"
}

# Asks the user to confirm the new configuration, the same way as "netplan try".
# Returns 1 if the configuration was reverted.
confirm_or_revert() {
  # Leave some time before the revert timer, so that the timer does not revert a configuration confirmed at the last moment
  local confirm_timeout=$((REVERT_TIMEOUT - 10))

  echo ""
  echo "The new network configuration is applied, but it is not confirmed yet."
  echo ""
  echo "To keep it:"
  echo "  1. Check that the network works, for example that you can open a new SSH session to the device"
  echo "  2. Press Enter in this terminal within $confirm_timeout seconds"
  echo ""
  echo "If this terminal lost its connection (for example because you changed the IP address it is connected to),"
  echo "log in again (using the new address) and confirm by running:"
  echo ""
  echo "  sudo systemctl stop $REVERT_UNIT.timer"
  echo ""
  echo "If the configuration is not confirmed in time, the previous network configuration is restored automatically."
  echo ""
  printf "Press Enter to keep the new network configuration ... "

  local remaining="$confirm_timeout"
  local read_status

  while [ "$remaining" -gt 0 ]; do
    read_status=0
    read -r -t 1 || read_status=$?

    if [ "$read_status" -eq 0 ]; then
      sudo systemctl stop "$REVERT_UNIT.timer"
      sudo rm -rf "$REVERT_DIR"
      echo "New network configuration kept"
      return 0
    elif [ "$read_status" -le 128 ]; then
      # Not a timeout, the terminal can not be read from. Keep waiting, it can still be confirmed from another session.
      sleep 1
    fi

    # The timer was stopped from another session
    if ! systemctl is-active --quiet "$REVERT_UNIT.timer"; then
      echo ""
      if sudo test -d "$REVERT_DIR"; then
        sudo rm -rf "$REVERT_DIR"
        echo "New network configuration was confirmed from another session"
        return 0
      fi
      echo "Previous network configuration was restored"
      return 1
    fi

    remaining=$((remaining - 1))
  done

  echo ""
  revert_now
  return 1
}
