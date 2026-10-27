#!/bin/bash

set -euo pipefail

# Network configs that match interfaces by their current name would no longer apply after the rename, and the device would lose
# network connection. Change them to match the interfaces by MAC address instead, which does not change.
match_network_configs_by_mac() {
	local dev name mac file

	for dev in /sys/class/net/*; do
		name=$(basename "$dev")

		# Only physical interfaces that are not using the old names yet
		[ -e "$dev/device" ] || continue
		[[ "$name" =~ ^(eth|wlan)[0-9]+$ ]] && continue
		mac=$(<"$dev/address")

		for file in /etc/netplan/*.yaml; do
			[ -e "$file" ] || continue

			# "match: name: <interface>" (used by configs created by NetworkManager)
			if sudo grep -qE "^[[:space:]]*name:[[:space:]]*\"?$name\"?[[:space:]]*$" "$file"; then
				sudo sed -i -E "s/^([[:space:]]*)name:[[:space:]]*\"?$name\"?[[:space:]]*$/\1macaddress: \"$mac\"/" "$file"
				echo "Changed $file to match $name by MAC address $mac"
			fi

			# "<interface>:" used directly as the interface ID, add a match by MAC address under it
			if sudo grep -qE "^[[:space:]]+$name:[[:space:]]*$" "$file"; then
				sudo awk -v name="$name" -v mac="$mac" '
					pending {
						match($0, /^[[:space:]]*/)
						indent = substr($0, 1, RLENGTH)
						if ($1 != "match:") {
							print indent "match:"
							print indent "  macaddress: \"" mac "\""
						}
						pending = 0
					}
					{ print }
					$0 ~ "^[[:space:]]+" name ":[[:space:]]*$" { pending = 1 }
				' "$file" | sudo tee "$file.tmp" >/dev/null
				sudo mv "$file.tmp" "$file"
				sudo chmod 600 "$file"
				echo "Changed $file to match $name by MAC address $mac"
			fi
		done

		# NetworkManager connections stored outside of netplan, bound to the interface name
		for file in /etc/NetworkManager/system-connections/*.nmconnection; do
			[ -e "$file" ] || continue

			if sudo grep -qx "interface-name=$name" "$file"; then
				sudo sed -i "/^interface-name=$name$/d" "$file"
				echo "Removed interface name $name from $file"
			fi
		done
	done
}

# Skip if already disabled
if grep -qw 'net.ifnames=0' /proc/cmdline && grep -qw 'biosdevname=0' /proc/cmdline; then
	if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
		whiptail --title "Fix network interface names" --msgbox "Option 'Predictable network interface names' is already disabled!" 0 0
	else
		echo "Option 'Predictable network interface names' is already disabled!"
	fi
	exit 0
fi

if [[ -f /etc/default/grub ]]; then
	# Device is using GRUB (e.g. Intel NUC)
	if ! grep -q 'net\.ifnames=0' /etc/default/grub; then
		sudo sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 net.ifnames=0"/' /etc/default/grub
	fi
	if ! grep -q 'biosdevname=0' /etc/default/grub; then
		sudo sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 biosdevname=0"/' /etc/default/grub
	fi
	sudo update-grub
elif [[ -f /boot/extlinux/extlinux.conf ]]; then
	# Device is using extlinux (e.g. NVIDIA Jetson)
	# Do not overwrite the backup of the original file when the script runs again
	if [[ ! -f /boot/extlinux/extlinux.conf.bak ]]; then
		echo "Creating backup of extlinux.conf at /boot/extlinux/extlinux.conf.bak"
		sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.bak
	fi
	if grep -q '^[[:space:]]*APPEND .*net\.ifnames=' /boot/extlinux/extlinux.conf; then
		sudo sed -i '/^[[:space:]]*APPEND / s/net\.ifnames=[^[:space:]]*/net.ifnames=0/g' /boot/extlinux/extlinux.conf
	else
		sudo sed -i '/^[[:space:]]*APPEND / s/$/ net.ifnames=0/' /boot/extlinux/extlinux.conf
	fi
	if grep -q '^[[:space:]]*APPEND .*biosdevname=' /boot/extlinux/extlinux.conf; then
		sudo sed -i '/^[[:space:]]*APPEND / s/biosdevname=[^[:space:]]*/biosdevname=0/g' /boot/extlinux/extlinux.conf
	else
		sudo sed -i '/^[[:space:]]*APPEND / s/$/ biosdevname=0/' /boot/extlinux/extlinux.conf
	fi
else
	echo "Could not find a supported bootloader config."
	echo "Expected /etc/default/grub or /boot/extlinux/extlinux.conf"
	exit 1
fi

match_network_configs_by_mac

if [[ "${NON_INTERACTIVE_MODE:-0}" -ne 1 ]]; then
	ret_val=0
	whiptail --title "Fix network interface names" --yesno "Option 'Predictable network interface names' has been disabled. Changes will apply only after system reboot. Do you want to reboot now?" --defaultno 0 0 || ret_val=$?

	if [ $ret_val -eq 0 ]; then
		sudo reboot
	else
		whiptail --title "Fix network interface names" --msgbox "Please reboot the system as soon as possible to apply the changes.\nNetwork configuration will not work correctly until then (wrong interface names)" 0 0
		exit 1
	fi
else
	echo "Option 'Predictable network interface names' has been disabled. Rebooting..."
	sudo reboot
fi
