#!/bin/bash
# this file is run by /etc/systemd/system/cust_rules.service prior to networkd but after the network devices are detected and populated
# the purpose is to intercept the network during boot, construct a network namespace named "customer" and place the ethernet devices
# in this namespace, then run NAC bypass or DHCP as required to gain access to the network.
echo "User: `whoami`" >> /tmp/test
echo "Network Status:" >> /tmp/test
echo "Carrier ENP1S0: `cat /sys/class/net/enp1s0/carrier`" >> /tmp/test
echo "Carrier ENP2S0: `cat /sys/class/net/enp2s0/carrier`" >> /tmp/test
USB0_CARRIER=cat /sys/class/net/usb0/carrier
if [[] $? -gt 0 ]]
then
  USB0_CARRIER=0
fi
echo "Carrier USB0: $USB_CARRIER" >> /tmp/test

networkctl -s -a >> /tmp/test
echo "" >> /tmp/test

ifconfig enp1s0 >> /tmp/test
ifconfig enp2s0 >> /tmp/test

# disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1

# configure the changed mac addr for the interfaces - they won't be picked up by netplan
macchanger -m 52:54:00:6b:3c:59 enp1s0
macchanger -m 52:54:00:6b:3c:5a enp2s0

# setup customer ns and add the enp1s0 and enp2s0 interfaces to it before the networks are configured (this should run on network-pre target in systemd)
ip netns add customer
ip netns exec customer sysctl net.ipv6.conf.all.disable_ipv6=1
ip link set enp1s0 netns customer
ip link set enp2s0 netns customer
ip netns exec customer ip addr add 127.0.0.1/8 dev lo
ip netns exec customer ip link set lo up

# disable some things that will leak our MAC.
ip netns exec customer ip link set enp1s0 multicast off
ip netns exec customer sysctl -w net.ipv4.igmp_link_local_mcast_reports=0
ip netns exec customer sysctl -w net.ipv4.igmp_max_memberships=0
ip netns exec customer sysctl -w net.ipv4.conf.enp1s0.igmpv3_unsolicited_report_interval=0
ip netns exec customer sysctl -w net.ipv4.conf.enp1s0.igmpv2_unsolicited_report_interval=0

# we always need this in order to get to the nessusd service located at 169.254.2.2!
ip link add tocustomer type veth peer name cust-veth
ip addr add 169.254.2.1/24 dev tocustomer
ip link set cust-veth netns customer
ip link set tocustomer up
ip netns exec customer ip addr add 169.254.2.2/24 dev cust-veth
ip netns exec customer ip link set cust-veth up
ip netns exec customer sysctl net.ipv4.ip_forward=1

ip netns exec customer /bin/bash -x /opt/detect.sh 2>&1 | tee -a /var/log/detect.log