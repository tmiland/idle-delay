#!/usr/bin/env bash

cfg_file=$HOME/.idle_delay/.idle_delay_config
# Read hidden configuration file with entries separated by " " into array
IFS=' ' read -ra CfgArr < $cfg_file

# Zenity form with current values in entry label
# because initializing multiple entry data fields not supported
output=$(zenity --forms --title="Screen blank power saving Configuration" \
    --text="Enter new settings or leave entries blank to keep (existing) settings" \
    --add-entry="Default idle delay : (${CfgArr[0]})" \
    --text="Enter new Phone settings or leave entries blank to keep (existing) settings" \
    --text="(Use command: 'usb-devices' to get this information)" \
    --add-entry="Vendor : (${CfgArr[1]})" \
    --add-entry="ProdID : (${CfgArr[2]})" \
    --add-entry="SerialNumber : (${CfgArr[3]})" \
    --add-entry="Idle time while connected : (${CfgArr[4]})" \
    --add-entry="Idle time when disconnected : (${CfgArr[5]})" \
    --add-entry="Phone Manufacturer (E.g Xiaomi) : (${CfgArr[6]})")

IFS='|' read -ra ZenArr <<<"$output" # Split zenity entries separated by "|" into array elements

# Update non-blank zenity array entries into configuration array
for i in "${!ZenArr[@]}"; do
    if [[ ${ZenArr[i]} != "" ]]; then CfgArr[i]=${ZenArr[i]} ; fi
done

# write hidden configuration file using array (fields automatically separated by " ")
if [[ ! -f cfg_file ]]; then
  touch $cfg_file
fi
echo "${CfgArr[@]}" > $cfg_file