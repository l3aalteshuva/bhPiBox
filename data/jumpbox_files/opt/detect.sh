#!/bin/bash
# this file detects the network setup that we will use - either NAC or 

# I think it makes OK sense for the cust_rules.service to run and setup things?  Networking is hard.
echo "===========================================================">> /var/log/detect.sh
echo "detect.sh was run `uptime` into boot at `date` by `whoami`" >> /var/log/detect.sh
echo "===========================================================">> /var/log/detect.sh

ip link set enp1s0 up
ip link set enp2s0 up
sleep 5
ifconfig >> /var/log/network_log
echo "`networkctl -a`" >> /var/log/detect.sh
echo "ethtool output: " >> /var/log/detect.sh

ethtool enp1s0 >> /var/log/detect.sh
ethtool enp2s0 >> /var/log/detect.sh

if [[ `cat /sys/class/net/enp2s0/carrier` -eq 1 ]]
then
    echo "CARRIER DETECTED ON ENP2S0\nNAC BYPASS MODE ENABLED" >> /var/log/network_log
    bash -x /opt/nac_bypass.sh -a -R 2>&1 | tee -a /var/log/nac_bypass.log
else
    echo "CARRIER ONLY ON ENP1S0\n DHCP MODE ENABLED" >> /var/log/network_log
    dhclient enp1s0 | tee -a /var/log/network_log
fi
