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
# Symlink: ln -sfn $HOME/.idle_delay/idle-delay.sh $HOME/.local/bin/idle-delay

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

install() {
url=https://github.com/tmiland/idle-delay/raw/main
idle_delay_config_url=$url/.idle_delay_config
idle_delay_config_sh_url=$url/idle-delay-config.sh
idle_delay_url=$url/idle-delay.sh
idle_delay_service=$url/idle-delay.service
systemd_user_folder=$HOME/.config/systemd/user
if ! [[ -d $systemd_user_folder ]]
then
  mkdir -p "$systemd_user_folder"
fi
local_bin_folder=$HOME/.local/bin
if ! [[ -d $local_bin_folder ]]
then
  mkdir -p "$local_bin_folder"
fi
if ! [[ $(command -v 'screen') ]]; then
  sudo apt install screen
fi
  download_files() {
  if [[ $(command -v 'curl') ]]; then
    curl -fsSLk "$idle_delay_config_url" > "${config_folder}"/.idle_delay_config
    curl -fsSLk "$idle_delay_config_sh_url" > "${config_folder}"/idle-delay-config.sh
    curl -fsSLk "$idle_delay_url" > "${config_folder}"/idle-delay.sh
    curl -fsSLk "$idle_delay_service" > "$systemd_user_folder"/idle-delay.service
  elif [[ $(command -v 'wget') ]]; then
    wget -q "$idle_delay_config_url" -O "${config_folder}"/.idle_delay_config
    wget -q "$idle_delay_config_sh_url" -O "${config_folder}"/idle-delay-config.sh
    wget -q "$idle_delay_url" -O "${config_folder}"/idle-delay.sh
    wget -q "$idle_delay_service" -O "$systemd_user_folder"/idle-delay.service
  else
    echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NC}"
    exit 0
  fi
}
echo ""
read -n1 -r -p "Idle-delay is ready to be installed, press any key to continue..."
echo ""
download_files
 ln -sfn "$HOME"/.idle_delay/idle-delay.sh "$HOME"/.local/bin/idle-delay
 chmod +x "$HOME"/.idle_delay/idle-delay.sh
 chmod +x "$HOME"/.idle_delay/idle-delay-config.sh
 "$HOME"/.local/bin/idle-delay -c
 sed -i "s|/usr/local/bin/idle-delay|$HOME/.local/bin/idle-delay|g" "$HOME"/.config/systemd/user/idle-delay.service
 systemctl --user enable idle-delay.service &&
 systemctl --user start idle-delay.service &&
 systemctl --user status idle-delay.service --no-pager
 echo "Install finished, now connect your phone and enjoy..."
 echo "You can resume screen with 'screen -r idle-delay' "
 echo "Restart service with 'systemdctl --user restart idle-delay' "
}

uninstall() {
  echo ""
  read -n1 -r -p "Idle-delay is ready to be installed, press any key to continue..."
  echo ""
  rm -rf "$config_folder"
  rm -rf "$HOME"/.local/bin/idle-delay
  systemctl --user disable idle-delay.service
  rm -rf "$HOME"/.config/systemd/user/idle-delay.service
  echo "Uninstall finished, have a good day..."
}

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "" $(basename "$0")
  echo
  printf "  --help               | -h           show this help message\\n"
  printf "  --idle-delay         | -id          set idle delay in minutes\\n"
  printf "  --current-idle-delay | -cid         show current idle-delay in minutes\\n"
  printf "  --auto-run           | -ar          auto run\\n"
  printf "  --config             | -c           run config dialog\\n"
  printf "  --install            | -i           install\\n"
  printf "  --uninstall          | -u           uninstall\\n"
  printf "\\n"
  echo
}

ARGS=()
while [[ $# -gt 0 ]]
do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
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
    --install | -i)
      install
      exit 0
      ;;
    --uninstall | -u)
      uninstall
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
