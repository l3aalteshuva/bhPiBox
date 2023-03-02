#!/bin/bash
NESSUS_CODE=***REMOVED***
cp -r /boot/firmware/nocloud/files/* /
cat <<EOF > /etc/netplan/50-cloud-init.yaml
    network:
      ethernets:
        enp1s0:
          dhcp4: false
          dhcp6: false
          accept-ra: false
          macaddress: 52:54:00:6b:3c:59
        enp2s0:
          dhcp4: false
          dhcp6: false
          accept-ra: false
          macaddress: 52:54:00:6b:3c:5a
        #usb0:
        #  addresses:
        #    - 192.168.0.2/24
        #  routes:
        #    - to: default
        #      via: 192.168.0.1
        #      metric: 1
        #    - to: $SERVER_ADDRESS
        #      via: 192.168.0.1
      version: 2
EOF
cd /opt && curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall && chmod 755 msfinstall && ./msfinstall
dpkg -i /opt/Nessus-*.deb
systemctl start nessusd.service
#- systemctl enable nessusd.service
#- bash -x /opt/install_nessus.sh | tee /opt/install_nessus.log
/opt/nessus/sbin/nessuscli fix --set listen_address=169.254.2.2
/opt/nessus/sbin/nessuscli fix --set auto_update=no
/opt/nessus/sbin/nessuscli fix --set send_telemetry=false
/opt/nessus/sbin/nessuscli fetch --register $NESSUS_CODE
/opt/nessus/sbin/nessuscli update --plugins-only
/usr/bin/python3 /opt/add_nessus_user.py
rm /opt/add_nessus_user.py

# This may not be the "best" place for this to go but my hope is that by placing the modification to the systemd service
# of nessus here, it won't matter if there's a major change to the servicefile in future nessus versions
# as long as they kick off the startscript with ExecStart=
sed -i /etc/systemd/system/nessusd.service -e 's/ExecStart=/ExecStart=ip netns exec customer /'

# After this you may lose internet unless the VPN is setup.
netplan apply
systemctl -f enable socksproxy
systemctl -f enable openvpn@client
systemctl -f enable cust_rules.service
systemctl -f enable connection_monitor.service
systemctl -f disable systemd-resolved
systemctl -f stop systemd-resolved
rm /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf
# raspi specific stuff so check we're raspi first by determining if the raspberrypi_hwmon driver is loaded.
if [ ! -z `lsmod | grep raspberrypi_hwmon | awk '{print $1}'` ]; then echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg && rm /usr/lib/systemd/network/10-raspi-eth0.link && rm /etc/netplan/50-cloud-init.yaml; fi;
  #- export DEBIAN_FRONTEND=noninteractive && apt-get update && apt-get -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -y --allow-downgrades --allow-remove-essential --allow-change-held-packages upgrade

# the default ubuntu sshd config doesn't allow password auth for some reason.  I want it.
sed -i /etc/ssh/sshd_config -e 's/PasswordAuthentication no/PasswordAuthentication yes/'

# add the hostname to /etc/hosts to preventt the "sudo: unable to resolve host" error.
echo "127.0.0.1 `hostname`" >> /etc/hosts

# the nessus service is modified to work properly in our networking environment, but tenable sometimes changes it.
chattr +i /etc/systemd/system/nessusd.service

# we do not want modifications to dhclient-script because I patched a bug in it preventing operation in namespaces
chattr +i /usr/sbin/dhclient-script

# Cleanup items:
# remove files from the boot sector to make room
rm -rf /boot/firmware/nocloud

# delete self.
rm /opt/jumpbox_cloudinit.sh
