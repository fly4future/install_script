#!/bin/bash

set -euo pipefail

# Skip if already disabled
if grep -qw 'net.ifnames=0' /proc/cmdline && grep -qw 'biosdevname=0' /proc/cmdline; then
	echo "Predictable network interface names are already disabled."
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
	echo "Creating backup of extlinux.conf at /boot/extlinux/extlinux.conf.bak"
	sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.bak
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

if [[ "$NON_INTERACTIVE_MODE" -ne 1 ]]; then
	whiptail --title "Fix network interface names" --yesno "Option 'Predictable network interface names' has been disabled. Changes will apply only after system reboot. Do you want to reboot now?" --defaultno 0 0
	ret_val=$?

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
