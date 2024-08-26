#!/usr/bin/env bash

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2023 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
## Uncomment for debugging purpose
if [[ $2 == "debug" ]]; then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
# Symlink: ln -sfn ~/.idle_delay/idle-delay.sh /usr/local/bin/idle-delay

config_folder=$HOME/.idle_delay
config=$config_folder/idle-delay-config.sh
cfg_file=$config_folder/idle_delay_config

if [[ ! -f $cfg_file ]]
then
 mkdir -p "$config_folder"
fi
if [[ -f $cfg_file ]]
then
  IFS=' ' read -ra cfg_array < $cfg_file
  idle_default="${cfg_array[0]}"
  Vendor="${cfg_array[1]}"
  ProdID="${cfg_array[2]}"
  SerialNumber="${cfg_array[3]}"
  idle_connected="${cfg_array[4]}"
  idle_disconnected="${cfg_array[5]}"
  Manufacturer="${cfg_array[6]}"
else
  idle_default=60
  Vendor=
  ProdID=
  SerialNumber=
  idle_connected=
  idle_disconnected=
  Manufacturer=
fi

config() {
  if [[ -f $config ]]
  then
    # shellcheck source=$config
    . "$config"
  fi
}

get_idle_delay=$(gsettings get org.gnome.desktop.session idle-delay | sed 's|uint32 ||g')

idle-delay() {
  gsettings set org.gnome.desktop.session idle-delay $(("$1"*60))
  echo "idle-delay was currently set to $((get_idle_delay/60)) minutes, now changed to $1"
}

auto-run() {
  while true
  do
    # Grab info from usb-devices
    get_usb_info=$(
      [[ $(
      usb-devices | grep -C 3 "Vendor=$Vendor ProdID=$ProdID" ||
      usb-devices | grep -C 3 "SerialNumber=$SerialNumber") =~ $Manufacturer ]] &&
      echo connected ||
      echo disconnected)
    get_idle_delay=$(gsettings get org.gnome.desktop.session idle-delay | sed 's|uint32 ||g')
    # Phone connected? Set idle-delay to 120 minutes
    if [[ $get_usb_info == "connected" ]]
    then
      if [[ $(( $get_idle_delay / 60 )) -eq $idle_disconnected ]]
      then
        echo "Phone is connected, idle-delay set to 120 minutes"
        idle-delay $idle_connected
        notify-send "Phone is connected, idle-delay set to 120 minutes"
      fi
      continue
    fi
    # Phone disconnected? Set idle-delay to 10 minutes
    if [[ $get_usb_info == "disconnected" ]]
    then
      if [[ $(( $get_idle_delay / 60 )) -eq $idle_connected ]]
      then
        echo "Phone is disconnected, idle-delay set to 10 minutes"
        idle-delay $idle_disconnected
        notify-send "Phone is disconnected, idle-delay set to 10 minutes"
      fi
      continue
    fi
    # Set to default if no phone is detected
    if ! [[ $get_usb_info == "disconnected" ]] || ! [[ $get_usb_info == "connected" ]]
    then 
      idle-delay "$idle_default"
    fi
    sleep 60 # reset once / minute.
  done # End of forever loop
}

ARGS=()
while [[ $# -gt 0 ]]
do
  case $1 in
    --idle-delay | -id) # Bash Space-Separated (e.g., --option argument)
      idle-delay "$2" # Source: https://stackoverflow.com/a/14203146
      shift # past argument
      shift # past value
      exit 0
      ;;
    --current-idle-delay | -cid)
      echo "Current idle delay: $((get_idle_delay/60))"
      exit 0
      ;;
    --auto-run | -ar)
      auto-run
      shift
      ;;
    --config | -c)
      config
      exit 0
      ;;
    -*|--*)
      printf "Unrecognized option: $1\\n\\n"
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${ARGS[@]}"
