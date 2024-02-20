#!/bin/bash

CHOICES=(
  "1" "The first option" ON
  "2" "The second option" ON
  "3" "The third option" OFF
  "4" "The fourth option" OFF
)

# Pass choices variable to whiptail
SELECTIONS=$(whiptail --separate-output --checklist "Choose options" 10 35 5 "${CHOICES[@]}" 3>&1 1>&2 2>&3)

echo "$SELECTIONS"

if [ -z "$SELECTIONS" ]; then
  echo "No option was selected (user hit Cancel or unselected all options)"
else
  for CHOICE in $SELECTIONS; do
    case "$CHOICE" in
    "1")
      echo "Option 1 was selected"
      ;;
    "2")
      echo "Option 2 was selected"
      ;;
    "3")
      echo "Option 3 was selected"
      ;;
    "4")
      echo "Option 4 was selected"
      ;;
    *)
      echo "Unsupported item $CHOICE!" >&2
      exit 1
      ;;
    esac
  done
fi
