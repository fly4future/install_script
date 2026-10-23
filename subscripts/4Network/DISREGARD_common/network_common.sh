#!/bin/bash

# Functions shared by the network scripts

NETPLAN_DIR="/etc/netplan"

# Renames a netplan config to *.yaml.bak, so that netplan ignores it.
disable_netplan_config() {
  local file="$1"
  local backup="$file.bak"

  sudo find "$NETPLAN_DIR" -maxdepth 1 -type f -name "$(basename "$file").bak.*" -delete
  sudo mv -f -- "$file" "$backup"
  echo "Disabled $file (renamed to $backup)"
}
