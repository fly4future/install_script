#!/bin/bash

source "$(dirname "$0")/DISREGARD_common/udev_rules_common.sh"

# Shows a dialog with a list of .rules files from the DISREGARD_udev_rules directory and allows the user to select one
template_file=$(choose_template_file)

# If no template file was found or selected, exit the script
if [ -z "$template_file" ]; then
  exit 1
fi

# Shows a dialog asking how to store the rule, either in a new file or appended to an existing one
# If the user chooses to create a new file, they are asked for the name of the new file.
# If a file with that name already exists, the script asks if the user wants to overwrite the file
write_mode=$(choose_write_mode "Udev config" "How do you want to store the selected udev rules?")
if [ "$write_mode" = "new" ]; then
  target_file_name=$(input_box "What should the new udev rules file be named?" "99-usb-serial-MRS.rules")
  if [ -z "$target_file_name" ]; then
    exit 1
  fi

  target_file=$(resolve_rules_target_path "$target_file_name")
  if [ -z "$target_file" ]; then
    exit 1
  fi

  if [ -e "$target_file" ]; then
    yesno_def_no "The file already exists: $target_file\n\nDo you want to overwrite this file with the selected rules instead?"
    ret_val=$?

    if [ $ret_val -eq 0 ]; then
      exit 1
    fi

  fi
elif [ "$write_mode" = "append" ]; then
  target_file=$(list_existing_udev_rules_file)
  if [ -z "$target_file" ]; then
    exit 1
  fi
else
  exit 1
fi

# Replace placeholder values in the rules template
template_contents=$(sed -e "s/TO_BE_REPLACED/$USER/g" "$template_file")

# Confirm before writing
yesno_def_yes "Write the selected rules to this file?\n\nTarget: $target_file\n\nTemplate: $(basename "$template_file")\n\nContents:\n\n$template_contents"
ret_val=$?

if [ ! $ret_val -eq 1 ]; then
  exit 1
fi

write_text_to_target "$target_file" "$write_mode" "$template_contents"
ret_val=$?
if [ $ret_val -eq 1 ]; then
  exit 1
fi

sudo chown root:root "$target_file"
sudo chmod 644 "$target_file"

sudo udevadm control --reload-rules
sudo udevadm trigger
