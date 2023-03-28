#!/bin/bash -x
set -x
static_opts="--config /etc/openvpn/client.conf"
add_opts=""
USB_RECONNECT=0

# Max number of restarts in THRESH seconds
MAX=5
THRESH=60
THEN=()

while :
do
  date >> /var/log/ovpn_wrapper.log
  echo "uptime: `uptime`" >> /var/log/ovpn_wrapper.log
  echo "reconnection: ${USB_RECONNECT}" >> /var/log/ovpn_wrapper.log
  echo "Entering while loop -- openvpn was not started yet or was stopped" >> /var/log/ovpn_wrapper.log

  if [[ -d /sys/class/net/usb0 && USB_RECONNECT -lt 1 ]]; then
      echo "found usb interface" >> /var/log/ovpn_wrapper.log
      remote="54.227.80.233"
      USB_RECONNECT=1
  else
      systemctl start socksproxy
      echo "no USB interface?" >> /var/log/ovpn_wrapper.log
      ifconfig -a >> /var/log/ovpn_wrapper.log
      remote="127.0.0.1"
      add_opts="--socks-proxy 169.254.2.2 1111 --port 1194"
  fi
  
  ovpn_cmd="/usr/sbin/openvpn ${static_opts} --remote ${remote} ${add_opts}"
  ${ovpn_cmd}
  echo "openvpn closed w/exit code $? at `date`" >> /var/log/openvpn_wrapper.log
  if [[ `cat /proc/uptime | awk '{print $1}' | cut -d. -f1` -lt 120 ]]
  then
    continue
  fi
  NOW=`date +%s`
  THEN+=($NOW)
  Z=0
  for i in ${!THEN[@]}
  do
    if [[ ${THEN[$i]} -gt $(($NOW-$THRESH)) ]]
    then
      Z=$((Z+1))
    else
      unset 'THEN[i]'
      fi
    if [[ $Z -gt MAX ]]
    then
      echo "openvpn wrapper detected openvpn restarting more than $MAX times in $THRESH seconds. Rebooting box to attempt to return to good state" >> /var/log/openvpn_wrapper.log
      init 6
    fi
  done

done
