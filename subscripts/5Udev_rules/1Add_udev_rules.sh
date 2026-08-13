#!/bin/bash

set -o pipefail

source "$(dirname "$0")/DISREGARD_common/udev_rules_common.sh"

choose_write_mode() {
  local title="$1"
  local prompt="$2"
  OPTIONS=(
    "1" "Create a new file"
    "2" "Append to existing file"
  )
  local choice
  choice=$(show_menu "$title" "$prompt")

  if [ $? -ne 0 ]; then
    exit 1
  fi

  if [ "$choice" = "1" ]; then
    printf '%s\n' "new"
  else
    printf '%s\n' "append"
  fi
}

choose_frame_template() {
  list_files_from_dir "$(dirname "$0")/DISREGARD_udev_rules" "Udev config" "Select which udev rules you want to use:" "No udev rules were found."
}

resolve_rules_target_path() {
  local file_name="$1"

  if [[ "$file_name" == /* ]]; then
    printf '%s\n' "$file_name"
    return
  fi

  if [[ "$file_name" != *.rules ]]; then
    file_name="${file_name}.rules"
  fi

  printf '/etc/udev/rules.d/%s\n' "$file_name"
}

get_device_info() {
  local device="$1"
  local device_path="/dev/$device"
  local device_info

  device_info=$(udevadm info "$device_path" | grep "S: serial/by-id/" || true)
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "DEVNAME" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_VENDOR_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_VENDOR_ID" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL_ID" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_MODEL=" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_SERIAL=" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_SERIAL_SHORT" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_PCI_CLASS_FROM_DATABASE" || true)"
  device_info="${device_info}\n$(udevadm info "$device_path" | grep "ID_PCI_SUBCLASS_FROM_DATABASE" || true)"

  printf '%b\n' "$device_info"
}

get_udev_value() {
  local device="$1"
  local key="$2"
  udevadm info "/dev/$device" | grep "$key" | head -n 1 | sed -e "s/^.*=//"
}

choose_mrs_board() {
  # Shows a dialog with a list of .rules files from the DISREGARD_udev_rules directory and allows the user to select one
  template_file=$(choose_frame_template)

  # If no template file was found or selected, exit the script
  if [ -z "$template_file" ]; then
    exit 1
  fi

  # Replace placeholder values in the rules template
  template_contents=$(sed -e "s/TO_BE_REPLACED/$USER/g" "$template_file")

  printf "%s\n\n" "$template_contents" >>"$tmp_file"
}

configure_connected_devices() {
  # List devices that the user might be interesting in adding udev rules for
  devices=$(ls /dev | grep -e ttyUSB -e ttyACM -e ttyTHS)

  if [ -z "$devices" ]; then
    msg_box "No devices matching the ttyUSBx, ttyACMx, or ttyTHS pattern found."
    exit 1
  fi

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

    # skip unless user answered Yes (return code 0)
    if [ $ret_val -ne 0 ]; then
      continue
    fi

    symlink=$(input_box "What should this device be named?")
    if [ -z "$symlink" ]; then
      continue
    fi

    rule_line="SUBSYSTEM==\"tty\", ATTRS{idVendor}==\"$idVendor\", ATTRS{idProduct}==\"$idProduct\""
    if [ -n "$Serial" ]; then
      rule_line="$rule_line, ATTRS{serial}==\"$Serial\""
    fi
    rule_line="$rule_line, SYMLINK+=\"$symlink\", OWNER=\"$USER\", MODE=\"0666\""

    generated_rules+="$rule_line"$'\n'
  done

  if [ -z "$generated_rules" ]; then
    msg_box "No udev rules were added."
    exit 1
  fi

  echo "$generated_rules" >>"$tmp_file"
}

choose_where_write_rules() {
  # Shows a dialog asking how to store the rule, either in a new file or appended to an existing one
  # If the user chooses to create a new file, they are asked for the name of the new file.
  # If a file with that name already exists, the script asks if the user wants to overwrite the file
  write_mode=$(choose_write_mode "Udev config" "How do you want to store these udev rules?")
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

      # If user did not agree to overwrite, abort
      if [ $ret_val -ne 0 ]; then
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
}

# Create a temp file for the rules before we write them to the final destination
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT # Ensure the temp file is removed when the script exits

# Ask if the user has a distribution board
yesno_def_yes "Do you have a MRS distribution board with existing udev .rules file?"
ret_val=$?

if [ $ret_val -eq 0 ]; then
  choose_mrs_board
fi

# Ask if the user wants to add rules for connected devices (ttyUSBx, ttyACMx, ttyTHSx)
yesno_def_yes "Do you want to add rules for connected devices (ttyUSBx, ttyACMx, ttyTHSx)?"
ret_val=$?

if [ $ret_val -eq 0 ]; then
  configure_connected_devices
fi

# If the temp file is empty at this point, there are no rules to write, so we can exit the script
if [ ! -s "$tmp_file" ]; then
  msg_box "No udev rules were selected or generated, so nothing to write."
  exit 1
fi

# Ask the user where they want to write the rules (new file, overwrite existing file, append to existing file)
choose_where_write_rules

sed -i '1s/^/# Following lines were added by MRS UAV System Install utility:\n/' $tmp_file

yesno_def_yes "Write the following rules to this file?\nTarget: $target_file\n\nNew rules:\n$(cat "$tmp_file")"
ret_val=$?

# abort if user did not confirm
if [ $ret_val -ne 0 ]; then
  exit 1
fi

if [ "$write_mode" = "new" ]; then
  # If the user chose to create a new file, we can just move the temp file to the target location
  sudo mv "$tmp_file" "$target_file"
else
  # If the user chose to append to an existing file, we need to concatenate the temp file with the existing file and write the result to the target location
  cat "$tmp_file" >>"$target_file"
  rm "$tmp_file"
fi

sudo chown root:root "$target_file"
sudo chmod 644 "$target_file"

sudo udevadm control --reload-rules
sudo udevadm trigger

exit 0
