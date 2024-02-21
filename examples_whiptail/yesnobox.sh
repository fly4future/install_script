#in this example, yes and no are swapped, so that the default choice is no. This is confusing, as we have to set yes to no and no to yes

whiptail --title "Example Dialog" --yesno "This is an example of a yes/no box." --yes-button "No" --no-button "Yes" 0 0
ret_val=$?

if [ $ret_val -eq 255 ]; then
  echo "User hit Escape"
  exit 0
elif [ $ret_val -eq 1 ]; then
  echo "User hit Yes"
elif [ $ret_val -eq 0 ]; then
  echo "User hit No"
else
  echo "Error state"
fi

