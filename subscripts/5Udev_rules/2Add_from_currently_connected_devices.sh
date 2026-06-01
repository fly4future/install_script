#!/bin/bash

source "$(dirname "$0")/DISREGARD_common/udev_rules_common.sh"

# Shows a dialog asking how to store the rule, either in a new file or appended to an existing one
# If the user chooses to create a new file, they are asked for the name of the new file.
# If a file with that name already exists, the script asks if the user wants to overwrite the file
write_mode=$(choose_write_mode "Udev config" "How do you want to store the device rules?")

if [ "$write_mode" = "new" ]; then
  target_file_name=$(input_box "What should the new udev rules file be named?" "99-usb-serial-MRS.rules")
  target_file=$(resolve_rules_target_path "$target_file_name")

  if [ -e "$target_file" ]; then
    yesno_def_no "The file already exists: $target_file\n\nDo you want to overwrite this file with the selected rules instead?"
    ret_val=$?

    if [ $ret_val -eq 0 ]; then
      exit 1
    fi
  fi
else
  target_file=$(list_existing_udev_rules_file)
  if [ -z "$target_file" ]; then
    exit 1
  fi
fi

# List devices that the user might be interesting in adding udev rules for
devices=$(ls /dev | grep -e ttyUSB -e ttyACM -e ttyTHS)

if [ -z "$devices" ]; then
  error_msg "No devices matching the ttyUSBx, ttyACMx, or ttyTHS pattern found."
  exit 1
fi

wrote_anything=false
generated_rules=""

# Loop over found devices and for each prompt user whether they want to add a udev rule for that device.
# If they do, ask what they want to name the symlink for that device and then write the corresponding udev rule to target file
for device in $devices; do
  device_info=$(get_device_info "$device")
  idVendor=$(get_udev_value "$device" "ID_VENDOR_ID")
  idProduct=$(get_udev_value "$device" "ID_MODEL_ID")
  Serial=$(get_udev_value "$device" "ID_SERIAL_SHORT")

  yesno_def_yes "Do you want to add a udev rule for this device? $device:\n$device_info"
  ret_val=$?

  if [ ! $ret_val -eq 1 ]; then
    continue
  fi

  symlink=$(input_box "What should this device be named?")

  rule_line="SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$idVendor\", ATTRS{idProduct}==\"$idProduct\""
  if [ -n "$Serial" ]; then
    rule_line="$rule_line, ATTRS{serial}==\"$Serial\""
  fi
  rule_line="$rule_line, SYMLINK+=\"$symlink\", OWNER=\"$USER\", MODE=\"0666\""

  if [ "$wrote_anything" = false ]; then
    generated_rules="# Following line was added by MRS UAV System Install utility:"$'\n'"${rule_line}"
    wrote_anything=true
  else
    generated_rules+=$'\n\n'"# Following line was added by MRS UAV System Install utility:"$'\n'"${rule_line}"
  fi
done

if [ "$wrote_anything" = false ]; then
  error_msg "No udev rules were added."
  exit 1
fi

yesno_def_yes "Write the generated rules to this file?\n\nTarget: $target_file\n\nGenerated rules:\n\n$generated_rules"
ret_val=$?

if [ ! $ret_val -eq 1 ]; then
  exit 1
fi

write_text_to_target "$target_file" "$write_mode" "$generated_rules"

sudo chown root:root "$target_file"
sudo chmod 644 "$target_file"

sudo udevadm control --reload-rules
sudo udevadm trigger
