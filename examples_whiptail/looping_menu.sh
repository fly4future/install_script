#!/bin/bash

OPTIONS=(
  1 "option 1"
  2 "option 2"
  3 "option 3"
  4 "Exit"
)

show_menu() {
  whiptail --title "MRS UAV System Install Utility" --menu "Choose an option:" 0 0 0 "${OPTIONS[@]}" 3>&1 1>&2 2>&3
}

main() {
  while true; do #infinite loop - menu reopens after a selection is made, unless cancel is selected
    clear
    choice=$(show_menu)
    case $choice in
      1)
        echo "Option 1 selected"
        # Your code to handle option 1 goes here
        ;;
      2)
        echo "Option 2 selected"
        # Your code to handle option 2 goes here
        ;;
      3)
        echo "Option 3 selected"
        # Your code to handle option 3 goes here
        ;;
      4)
        exit 1
        ;;
      *) # the default case, also called when cancel is selected
        exit 1
        ;;
    esac
    read -p "${blink}${bold}Hit enter to continue ...${normal}" #wait for user input before returning to the menu
  done
}

main
exit 0
