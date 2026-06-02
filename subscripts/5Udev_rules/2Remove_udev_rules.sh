#!/bin/bash

source "$(dirname "$0")/DISREGARD_common/udev_rules_common.sh"

target_file=$(list_existing_udev_rules_file)
if [ -z "$target_file" ]; then
  exit 1
fi

yesno_def_yes "Do you want to delete this file?\nFile: $target_file\nContents:\n$(cat "$target_file")"
ret_val=$?

# abort if user did not confirm
if [ $ret_val -ne 0 ]; then
  exit 1
fi

sudo rm "$target_file"

sudo udevadm control --reload-rules
sudo udevadm trigger

exit 1 # Exit 1 so that we go back to the udev menu instead of the main menu
