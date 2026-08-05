# Install script

This repository contains scripts for flashing and configuring computers for use in F4F/MRS.

## Configuration utility

Use these scripts directly on the host that you want to configure.

### Interactive configuration utility

Clone this repository to the device you want to configure and run the setup utility script using `./setup_utility.sh`.

### Non-interactive configuration utility

Use `auto_setup_utility.sh` to run setup non-interactively from a profile file, which contains all the necessary information and toggles for the configuration. This is useful for automating the setup process or for running it on multiple devices with the same configuration.

  ```sh
  ./auto_setup_utility.sh profiles/sample.conf
  ```

Profile files are located in `profiles/` directly. They contain a list of toggles and variables for guiding the configuration.
A new profile can be created by copying and modifying the `sample.conf` file as needed.

Note that not all functionality of the manual setup utilities is available in the non-interactive version. Most notably:

- Switching from `networkd` back to `NetworkManager`, since it is only there for debugging purposes
- Installation and uninstallation of ROS without docker (directly with `apt`). This can be implemented in the future.
- MRS internal only configuration. Can be implemented in the future.
- Disregarded scripts


## Flashing Jetson devices

Requirements:

- A Linux computer
- USB cable to connect to the Jetson device
- Jumper cable (for devices without reset button)

Run the script `jetson_flash.sh` on your own computer. The script will download the necessary files (BSP and root filesystem) and flash them to the Jetson device.

The script will prompt you for the exact version of Jetson Linux you want to install. Available versions are listed here: <https://developer.nvidia.com/embedded/jetson-linux-archive>. You can find the links to the BSP and root filesystem by clicking on the desired version and on the next page copying the links for "Driver Package (BSP) and Sample Root Filesystem".

The script will also ask you whether you want to keep the temporary files after flashing.
If you need to flash multiple devices then select yes to avoid re-downloading them.
A separate directory will be created for each version of Jetson Linux, by default at `$HOME/jetson_flash_tmp_VERSION/`.
In case you change your mind you can always delete the entire directory.
The size of this directory is about 75 GB.

After the script completes, you can continue configuration on the Jetson device by cloning this repository and running the `setup_utility.sh` script.


## Development instructions

The interactive wizard automatically detects `.sh` scripts in the `subscripts/` directory and it's subdirectories. To add a new script, simply place it in the appropriate directory and ensure it has execute permissions (`chmod +x script.sh`).

The wizard entry for the script is based on the script's filename. Underscores are replace with spaces.
If you don't want a script (or other file) to be detected by the wizard, put it into a subdirectory that includes `DISREGARD` in its name. The wizard will ignore all files in such directories.

When writing the scripts do the following:

- use `set -euo pipefail` at the top of the script to ensure that it exits on errors, unset variables, and failed pipes
- check whether the commands you are using are available on the system, and if not, install them
- if you want to script to be used non-interactively, you should check if `NON_INTERACTIVE_MODE=1`, and if so provide a way for the script to execute without using `whiptail`, `read`, or other interactive commands
- return `0` on success and `1` on failure. Note that if you print some output on the console the user might not see it. Use `read -p "Press enter to continue"` to pause the script and allow the user to read the output before continuing, but make sure to check for `NON_INTERACTIVE_MODE=1` and skip the pause in that case.

  ```sh
  if [[ "$NON_INTERACTIVE_MODE" -ne 1 ]]; then
    read -p "Press Enter to continue..."
  fi
  ```
  
