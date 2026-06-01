# Install-script

## Flashing Jetson devices

Requirements:

- A Linux computer
- USB cable to connect to the Jetson device
- Jumper cable (for devices without reset button)

Run the script `jetson_flash.sh` on your own computer. The script will download the necessary files (BSP and root filesystem) and flash them to the Jetson device.

The script will prompt you for the exact version of Jetson Linux you want to install. Available versions are listed here: <https://developer.nvidia.com/embedded/jetson-linux-archive>. You can find the links to the BSP and root filesystem by clicking on the desired version and on the next page copying the links for "Driver Package (BSP) and Sample Root Filesystem".

The script will also ask you whether you want to keep the temporary files after flashing. If you need to flash multiple devices then select yes to avoid re-downloading them.
In case you change your mind you can always delete the entire directory (by default `~/jetson_configure_tmp`).
The size of this directory is about 75 GB.

After the script completes, you can continue configuration on the Jetson device by cloning this repository and running one of the `setup_utility.sh` scripts.

## Configuration utility

- Run the script with "setup_utility.sh" in the root directory of the repository.
- The menu items will be automatically generated from the "subscripts"
   folder
- Scripts and folders will appear in the menu as items or
   folders.

   You can easily add new functionality by putting new scripts into the
   subscripts folder. See examples of menus in the "examples_whiptail"
   folder.
