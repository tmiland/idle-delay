#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091

## Author: Tommy Miland (@tmiland) - Copyright (c) 2026


######################################################################
####                          idle-delay                          ####
####             Auto adjust screen blank idle-delay              ####
####                  based on phone connection                   ####
####                   Maintained by @tmiland                     ####
######################################################################


VERSION='1.0.2'


#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2026 Tommy Miland
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
cfg_file=$config_folder/.idle_delay_config
log_file=$config_folder/idle-delay.log
# Auto-add newly seen phones with these defaults (set auto_add_phones=0 to disable)
auto_add_phones=1
auto_add_connected=120
auto_add_disconnected=10

if [[ ! -f $cfg_file ]]
then
 mkdir -p "$config_folder"
fi
# Config format (one phone per line):
# idle_default Vendor ProdID SerialNumber idle_connected idle_disconnected Manufacturer
idle_default=60
phone_vendor=()
phone_prodid=()
phone_serial=()
phone_connected_time=()
phone_disconnected_time=()
phone_manufacturer=()
last_phone=-1

if [[ -f $cfg_file ]]
then
  while IFS=' ' read -r c_default c_vendor c_prodid c_serial c_conn c_disc c_manu
  do
    [[ $c_default == '#'* ]] && continue
    [[ -z ${c_vendor}${c_prodid}${c_serial} ]] && continue
    [[ -n $c_default ]] && idle_default=$c_default
    phone_vendor+=("$c_vendor")
    phone_prodid+=("$c_prodid")
    phone_serial+=("$c_serial")
    phone_connected_time+=("$c_conn")
    phone_disconnected_time+=("$c_disc")
    phone_manufacturer+=("$c_manu")
  done < "$cfg_file"
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
  gsettings set org.gnome.desktop.session idle-delay $(( $1 * 60 ))
  echo "idle-delay was currently set to $(( get_idle_delay / 60 )) minutes, now changed to $1"
}

auto-run() {
  prev_state=""
  prev_matched=""
  while true
  do
    # Nothing configured: leave idle-delay alone
    if [[ ${#phone_vendor[@]} -eq 0 ]]
    then
      sleep 7
      continue
    fi
    # Match any configured phone against a single usb-devices snapshot
    usb_snapshot=$(usb-devices)

    # Auto-add unknown phones: MTP/ADB composite interface with a serial number
    if [[ $auto_add_phones -eq 1 ]]
    then
      while IFS='|' read -r u_vendor u_prodid u_serial u_manufacturer
      do
        [[ -z $u_serial ]] && continue
        known=0
        for existing_serial in "${phone_serial[@]}"
        do
          [[ $existing_serial == "$u_serial" ]] && known=1 && break
        done
        [[ $known -eq 1 ]] && continue
        printf '%s %s %s %s %s %s %s\n' \
          "$idle_default" "$u_vendor" "$u_prodid" "$u_serial" \
          "$auto_add_connected" "$auto_add_disconnected" \
          "${u_manufacturer:-Unknown}" >> "$cfg_file"
        phone_vendor+=("$u_vendor")
        phone_prodid+=("$u_prodid")
        phone_serial+=("$u_serial")
        phone_connected_time+=("$auto_add_connected")
        phone_disconnected_time+=("$auto_add_disconnected")
        phone_manufacturer+=("${u_manufacturer:-Unknown}")
        printf '%s auto-added %s %s:%s serial=%s\n' \
          "$(date '+%F %T')" "${u_manufacturer:-Unknown}" \
          "$u_vendor" "$u_prodid" "$u_serial" >> "$log_file"
        notify-send \
        --hint=string:sound-name:dialog-information \
        --app-icon=dialog-information-symbolic \
        --icon=phone-symbolic \
        "Idle Delay" \
        "New phone added: ${u_manufacturer:-Unknown} ($u_serial)"
      done < <(printf '%s\n' "$usb_snapshot" | awk '
        BEGIN { RS=""; FS="\n" }
        {
          v=""; p=""; s=""; m=""; mtp=0
          for (i=1; i<=NF; i++) {
            line=$i
            if (line ~ /^P:/ && line ~ /Vendor=/) {
              sub(/^P:[ \t]*Vendor=/, "", line)
              split(line, a, /[ =]/)
              v=a[1]; p=a[3]
            } else if (line ~ /^S:/ && line ~ /SerialNumber=/) {
              sub(/^S:[ \t]*SerialNumber=/, "", line); s=line
            } else if (line ~ /^S:/ && line ~ /Manufacturer=/) {
              sub(/^S:[ \t]*Manufacturer=/, "", line); m=line
            } else if (line ~ /Sub=42/ && line ~ /Cls=ff\(vend\.\)/) {
              mtp=1
            }
          }
          if (v != "" && s != "" && mtp) print v "|" p "|" s "|" m
        }')
    fi

    active_phone=-1
    matched=()
    for i in "${!phone_vendor[@]}"
    do
      if printf '%s\n' "$usb_snapshot" | awk \
        -v v="${phone_vendor[$i]}" \
        -v p="${phone_prodid[$i]}" \
        -v s="${phone_serial[$i]}" \
        -v m="${phone_manufacturer[$i]}" '
          BEGIN { RS=""; found=0 }
          {
            if ((v != "" && p != "" && $0 ~ ("Vendor=" v " ProdID=" p)) ||
                (s != "" && $0 ~ ("SerialNumber=" s))) {
              if (m == "" || $0 ~ ("Manufacturer=" m)) { found=1; exit }
            }
          }
          END { exit !found }'
      then
        matched+=("$i")
        [[ $active_phone -lt 0 ]] && active_phone=$i
      fi
    done
    if [[ $active_phone -ge 0 ]]
    then
      get_usb_info="connected"
    else
      get_usb_info="disconnected"
    fi
    if [[ ${matched[*]} != "$prev_matched" ]]
    then
      printf '%s state=%s phones=[%s]\n' \
        "$(date '+%F %T')" "$get_usb_info" "${matched[*]}" >> "$log_file"
      prev_matched="${matched[*]}"
    fi

    if [[ $active_phone -ge 0 ]]
    then
      idle_connected="${phone_connected_time[$active_phone]}"
      idle_disconnected="${phone_disconnected_time[$active_phone]}"
      last_phone=$active_phone
    else
      idx=$last_phone
      [[ $idx -lt 0 ]] && idx=0
      idle_connected="${phone_connected_time[$idx]}"
      idle_disconnected="${phone_disconnected_time[$idx]}"
    fi

    get_idle_delay=$(gsettings get org.gnome.desktop.session idle-delay | sed 's|uint32 ||g')
    # React to real state changes only, so a manual idle-delay is not overridden
    if [[ $get_usb_info == "connected" && $prev_state != "connected" ]]
    then
      echo "Phone is connected, idle-delay set to $idle_connected minutes"
      idle-delay "$idle_connected"
      printf '%s connected phone=%s idle=%s\n' \
        "$(date '+%F %T')" "$active_phone" "$idle_connected" >> "$log_file"
      notify-send \
      --hint=string:sound-name:dialog-information \
      --app-icon=dialog-information-symbolic \
      --icon=phone-symbolic \
      "Idle Delay" \
      "Phone is connected, idle-delay set to $idle_connected minutes"
    fi
    if [[ $get_usb_info == "disconnected" && $prev_state != "disconnected" ]]
    then
      echo "Phone is disconnected, idle-delay set to $idle_disconnected minutes"
      idle-delay "$idle_disconnected"
      printf '%s disconnected idle=%s\n' \
        "$(date '+%F %T')" "$idle_disconnected" >> "$log_file"
      notify-send \
      --hint=string:sound-name:dialog-information \
      --app-icon=dialog-information-symbolic \
      --icon=phone-symbolic \
      "Idle Delay" \
      "Phone is disconnected, idle-delay set to $idle_disconnected minutes"
    fi
    prev_state=$get_usb_info
    sleep 7 # reset once / minute.
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
if ! [[ $(command -v 'libnotify-bin') ]]; then
  sudo apt install libnotify-bin
fi
# Set idle-delay to default if it isn't already
if [[ ! $get_idle_delay -eq $idle_default ]]
then
  idle-delay "$idle_default"
fi
  download_files() {
  if [[ $(command -v 'curl') ]]; then
    if [[ ! -f $cfg_file ]]
    then
      curl -fsSLk "$idle_delay_config_url" > "${config_folder}"/.idle_delay_config
    fi
    curl -fsSLk "$idle_delay_config_sh_url" > "${config_folder}"/idle-delay-config.sh
    curl -fsSLk "$idle_delay_url" > "${config_folder}"/idle-delay.sh
    curl -fsSLk "$idle_delay_service" > "$systemd_user_folder"/idle-delay.service
  elif [[ $(command -v 'wget') ]]; then
    if [[ ! -f $cfg_file ]]
    then
      wget -q "$idle_delay_config_url" -O "${config_folder}"/.idle_delay_config
    fi
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
 echo "Restart service with 'systemctl --user restart idle-delay.service' "
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
    --*|-*)
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
