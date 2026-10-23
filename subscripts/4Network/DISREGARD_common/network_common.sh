#!/bin/bash

# Functions shared by the network scripts

NETPLAN_DIR="/etc/netplan"

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
