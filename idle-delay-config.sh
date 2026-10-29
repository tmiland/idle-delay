#!/usr/bin/env bash

cfg_file=$HOME/.idle_delay/.idle_delay_config

# First configured phone is edited; any extra phone lines are preserved as-is.
first_line=""
rest_lines=()
if [[ -f $cfg_file ]]; then
  while IFS= read -r line; do
    [[ -z $line || $line == '#'* ]] && continue
    if [[ -z $first_line ]]; then first_line=$line; else rest_lines+=("$line"); fi
  done < "$cfg_file"
fi
IFS=' ' read -ra CfgArr <<< "$first_line"

# Zenity form with current values in entry label
# because initializing multiple entry data fields not supported
output=$(zenity --forms --title="Screen blank power saving Configuration" \
    --text="Edit the first phone. Extra configured phones are kept unchanged." \
    --text="(Use command: 'usb-devices' to get this information)" \
    --add-entry="Default idle delay : (${CfgArr[0]:-60})" \
    --add-entry="Vendor : (${CfgArr[1]})" \
    --add-entry="ProdID : (${CfgArr[2]})" \
    --add-entry="SerialNumber : (${CfgArr[3]})" \
    --add-entry="Idle time while connected : (${CfgArr[4]})" \
    --add-entry="Idle time when disconnected : (${CfgArr[5]})" \
    --add-entry="Phone Manufacturer (E.g Xiaomi) : (${CfgArr[6]})" \
    --text="Add another phone (leave all blank to skip)" \
    --add-entry="New Vendor :" \
    --add-entry="New ProdID :" \
    --add-entry="New SerialNumber :" \
    --add-entry="New idle time while connected :" \
    --add-entry="New idle time when disconnected :" \
    --add-entry="New Manufacturer :")

[[ -z $output ]] && exit 0
IFS='|' read -ra ZenArr <<<"$output" # Split zenity entries separated by "|" into array elements

# Update non-blank zenity array entries into configuration array
for i in 0 1 2 3 4 5 6; do
    if [[ ${ZenArr[i]} != "" ]]; then CfgArr[i]=${ZenArr[i]} ; fi
done
CfgArr[0]=${CfgArr[0]:-60}

new_phone=("${ZenArr[@]:7:6}")

# write hidden configuration file using array (fields automatically separated by " ")
{
  if [[ -n ${CfgArr[1]}${CfgArr[2]}${CfgArr[3]} ]]; then
    echo "${CfgArr[*]}"
  fi
  for line in "${rest_lines[@]}"; do
    echo "$line"
  done
  if [[ -n ${new_phone[0]} && -n ${new_phone[1]} && -n ${new_phone[2]} ]]; then
    echo "${new_phone[*]}"
  fi
} > "$cfg_file"
