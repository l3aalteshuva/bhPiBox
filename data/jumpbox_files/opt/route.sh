#!/bin/bash
# This file is run by the connection_monitor.py service when the LTE interface is not present or is detected as unstable.
# this will create a veth interface pair between default and customer namespace, and then route *only* the openvpn traffic
# out to the customer namepsace to be routed through the customer's network.
set -x
# Grab the only valid remote directive in the openvpn file.
if [[ `cat /sys/class/net/enp2s0/carrier` -eq 0 ]]
then
    echo "No LTE and no NAC bypass mode.  Adding masquerade rules"
    ip netns exec customer iptables -t nat -A POSTROUTING -s 169.254.2.0/24 -j MASQUERADE
fi
systemctl restart openvpn@client
while [[ -z `ip addr | grep tun0` ]]; do
    sleep 1
    echo "waiting for openvpn to come up"
    # note: if this hangs, connection_monitor.py should reboot the system.
done

