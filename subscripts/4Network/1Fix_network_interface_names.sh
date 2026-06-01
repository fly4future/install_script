#!/bin/bash

set -e

if [[ -f /etc/default/grub ]]; then
    # Device is using GRUB (e.g. Intel NUC)
    sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/g' /etc/default/grub
    sudo update-grub
elif [[ -f /boot/extlinux/extlinux.conf ]]; then
    # Device is using extlinux (e.g. NVIDIA Jetson)
	sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.bak
	if grep -q 'net.ifnames=' /boot/extlinux/extlinux.conf; then
		sudo sed -i 's/net.ifnames=[^[:space:]]*/net.ifnames=0/g' /boot/extlinux/extlinux.conf
	else
		sudo sed -i '/^[[:space:]]*APPEND / s/$/ net.ifnames=0/' /boot/extlinux/extlinux.conf
	fi
	if grep -q 'biosdevname=' /boot/extlinux/extlinux.conf; then
		sudo sed -i 's/biosdevname=[^[:space:]]*/biosdevname=0/g' /boot/extlinux/extlinux.conf
	else
		sudo sed -i '/^[[:space:]]*APPEND / s/$/ biosdevname=0/' /boot/extlinux/extlinux.conf
	fi
else
	echo "Could not find a supported bootloader config."
	echo "Expected /etc/default/grub or /boot/extlinux/extlinux.conf"
	exit 1
fi

echo " "
echo "Changes will be applied only after system reboot"
exit 0
