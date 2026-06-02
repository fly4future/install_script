#!/bin/bash

source "$(dirname "$0")/DISREGARD_common/udev_rules_common.sh"

target_file=$(list_existing_udev_rules_file)
if [ -z "$target_file" ]; then
  exit 1
fi

msg_box "File: $target_file\nContents:\n$(cat "$target_file")"

exit 1 # Exit 1 so that we go back to the udev menu instead of the main menu
