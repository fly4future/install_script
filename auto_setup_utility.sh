#!/bin/bash

set -u

# Write all output to the console and to a log file
LOG_FILE="auto_setup_utility.log"
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
    echo "Usage: $0 <profile-file>"
}

# Checks if a profile variable is set to true
profile_var_is_true() {
  local var_name="$1"
  local value=""
  eval "value=\${${var_name}:-}"
  if [ "$value" = "true" ]; then
    return 0
  fi
  return 1
}

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

PROFILE_FILE="$1"
DIR="$(dirname "$(readlink -f "$0")")"

if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: Profile file does not exist: $PROFILE_FILE"
    exit 1
fi

# Automatically export all variables loaded from the profile file
set -a
# shellcheck disable=SC1090
source "$PROFILE_FILE"
set +a

export NON_INTERACTIVE_MODE=1

log() {
    echo "[$(date '+%F %T')] [AUTO] $*"
}

# Print a profile file with basic ANSI color highlighting:
# - comments in dim gray
# - variable names in cyan
# - equals sign in default color
# - values in green
display_profile_colored() {
    local file="$1"
    awk '
  BEGIN { in_multiline = 0 }
  {
    # 1. Handle inside a multiline string value
    if (in_multiline) {
        t = $0
        gsub(/\\"/, "", t)   # Remove escaped quotes so they dont throw off the count
        q = gsub(/"/, "", t)  # Count remaining double quotes
        
        # If there is an odd number of quotes, the multiline string ends here
        if (q % 2 != 0) {
            in_multiline = 0
        }
        printf "    \033[32m%s\033[0m\n", $0
        next
    }

    # 2. Check if the entire line is a comment
    if ($0 ~ /^[[:space:]]*#/) {
        printf "    \033[90m%s\033[0m\n", $0
        next
    }

    # 3. Handle standard lines and variable assignments
    pos = index($0, "=")    
    if (pos > 0) {
        name = substr($0, 1, pos-1)
        value = substr($0, pos+1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        sub(/^[[:space:]]+/, "", value)

        # Check if this assignment opens a multiline string
        t = value
        gsub(/\\"/, "", t)
        q = gsub(/"/, "", t)

        if (q % 2 != 0) {
            # Odd number of quotes means a multiline string starts here
            in_multiline = 1
            printf "    \033[36m%s\033[0m=\033[32m%s\033[0m\n", name, value
        } else {
            # Standard single-line assignment; allow inline comments
            comment = ""
            posc = index(value, "#")
            if (posc > 0) {
                comment = substr(value, posc)
                value = substr(value, 1, posc-1)
                gsub(/[[:space:]]+$/, "", value)
            }

            if (length(comment) > 0) {
                printf "    \033[36m%s\033[0m=\033[32m%s\033[0m \033[90m%s\033[0m\n", name, value, comment
            } else {
                printf "    \033[36m%s\033[0m=\033[32m%s\033[0m\n", name, value
            }
        }
    } else {
        # If the line is not a comment and has no equals sign, print as-is
        printf "    %s\n", $0
    }
  }
    ' "$file"
}

# Exit immediately on Ctrl+C or termination signals; kill child processes.
trap_handler() {
    log "Interrupted by user; exiting."
    # kill any child processes spawned by this script
    pkill -P $$ 2>/dev/null || true
    exit 130
}
trap 'trap_handler' INT TERM

# Checks if the toggle variable for this step is enabled in the profile and if so runs it, otherwise skips
run_step() {
    local toggle_var="$1"
    local step_name="$2"
    local script_path="$3"
    shift 3

    if ! profile_var_is_true "$toggle_var"; then
        log "Skipping $step_name ($toggle_var is disabled)"
        return 0
    fi

    if [ ! -f "$script_path" ]; then
        log "ERROR: Missing script for $step_name: $script_path"
        return 1
    fi

    log "Running $step_name"
    bash "$script_path" "$@"
    local rc=$?

    if [ "$rc" -ne 0 ]; then
        log "ERROR: $step_name failed with exit code $rc"
        return "$rc"
    fi

    log "Completed $step_name"
    return 0
}

main() {
    log "Loaded profile: $(basename "$PROFILE_FILE")"

    # Show the loaded profile to the user for confirmation
    log "Profile contents:"
    display_profile_colored "$PROFILE_FILE"

    echo
    echo "Confirm and proceed? Press Enter to continue or Ctrl+C to abort."
    read -r

    run_step "RUN_UPDATE_SYSTEM" "Update system" "$DIR/subscripts/1Update/1Update_system.sh" || exit 1
    run_step "RUN_UPDATE_SYSTEM_AND_ROS" "Update system and ROS" "$DIR/subscripts/1Update/2Update_system_and_baremetal_ROS.sh" || exit 1

    run_step "RUN_INSTALL_BASIC_PACKAGES" "Install basic packages" "$DIR/subscripts/2Install/1Install_basic_packages_(vim,_git,_curl,_ranger)_...sh" || exit 1
    run_step "RUN_INSTALL_DOCKER" "Install Docker" "$DIR/subscripts/2Install/6Install_Docker.sh" || exit 1
    run_step "RUN_INSTALL_INTEL_WIFI_DRIVERS" "Install Intel WiFi drivers" "$DIR/subscripts/2Install/7Install_Intel_WiFi_drivers.sh" || exit 1

    run_step "RUN_DISABLE_POWER_SAVING" "Disable power saving" "$DIR/subscripts/3PostInstall/2Disable_power_saving.sh" || exit 1
    run_step "RUN_GENERATE_SSH_CONFIG" "Generate SSH config" "$DIR/subscripts/3PostInstall/3Generate_SSH_config.sh" || exit 1
    run_step "RUN_SET_SWAP_16GB" "Set swap to 16GB" "$DIR/subscripts/3PostInstall/4Set_Swap_to_16GB.sh" || exit 1
    run_step "RUN_CLEANUP_HOME_DIRECTORY" "Cleanup home directory" "$DIR/subscripts/3PostInstall/5Cleanup_home_directory.sh" || exit 1
    run_step "RUN_SETUP_RTC_ON_JETSON" "Setup RTC on Jetson" "$DIR/subscripts/3PostInstall/6Setup_RTC_on_Jetson.sh" || exit 1
    run_step "RUN_SET_TIMEZONE_TO_PRAGUE" "Set timezone to Europe/Prague" "$DIR/subscripts/3PostInstall/7Set_timezone_to_Prague.sh" || exit 1

    run_step "RUN_FIX_NETWORK_INTERFACE_NAMES" "Fix network interface names" "$DIR/subscripts/4Network/1Fix_network_interface_names.sh" || exit 1

    run_step "RUN_SET_WALLPAPER" "Set wallpaper" "$DIR/subscripts/6Branding/1Set_wallpaper.sh" || exit 1
    run_step "RUN_SET_PROFILE_PICTURE" "Set profile picture" "$DIR/subscripts/6Branding/2Set_profile_picture.sh" "${TARGET_VARIANT:-}" || exit 1
    run_step "RUN_SET_TERMINAL_MOTD" "Set terminal MOTD" "$DIR/subscripts/6Branding/3Set_terminal_MOTD.sh" "${TARGET_VARIANT:-}" || exit 1

    log "Done."
}

main
