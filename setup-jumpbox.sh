#!/bin/bash
export OPNAME=$1
export CLIENTS=1
export C2_DOMAIN=$2
export ISO_FILE_LOCATION=$3
#export PLAINTEXT_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c13;echo;)
# DEBUG DO NOT USE IN PROD
export PLAINTEXT_PASSWORD="CrossTesting!"
export PASSWORD=`openssl passwd -6 $PLAINTEXT_PASSWORD`
export HOSTNAME=$(< /dev/urandom tr -dc A-Z-0-9 | head -c8;echo;)
export TMP_LOC=`pwd`/data/state/tmp/
export CUR_LOC=`pwd`

# check root.
if (( $EUID != 0 )); then
    echo "The creation of the raspi image requires losetup, which requires root.\nPlease re-run this program as root."
    exit 255
fi

if [[ -z "$1" || -z "$2" || -z $3 ]]
then
      echo "Missing arguments"
      echo ""
      echo "Usage:"
      echo "    ./setup-jumpbox.sh [engagement_name] [c2_domain] [Raspi_Img_location]"
      echo ""
      exit 254
fi

# we treat this folder the same as the server (pretend that this is the jumpbox /)
JUMPBOX_LOC=`pwd`/jumpboxes/$OPNAME
mkdir -p $JUMPBOX_LOC/root
cp -r data/jumpbox_files/* $JUMPBOX_LOC/root

# TODO: this isn't really a good way of doing this...
echo "$OPNAME:$PLAINTEXT_PASSWORD" >> $JUMPBOX_LOC/password.txt
cp $ISO_FILE_LOCATION $JUMPBOX_LOC/raspi.img

TMP_LOC=$JUMPBOX_LOC/iso
mkdir -p $TMP_LOC

LOOP_DEVICE=`losetup --show -fP $JUMPBOX_LOC/raspi.img`

# mount the boot partition of the iso to `pwd`/jumpboxes/$NAME/iso/
mount ${LOOP_DEVICE}p1 ${TMP_LOC}

# Create empty meta-data file:
mkdir -p ${TMP_LOC}/nocloud/
touch ${TMP_LOC}/nocloud/meta-data

# this will hold files to be xfer'd to root partition on rapi setup proceess 
mkdir ${TMP_LOC}/nocloud/files/
#cp -r data/jumpbox_files/* $TMP_LOC/nocloud/files/

# Copy user-data file:
envsubst < data/user-data.template > ${TMP_LOC}/nocloud/user-data

# generate the socksproxy bridge service file
envsubst < data/socksproxy.service.template > $JUMPBOX_LOC/root/etc/systemd/system/socksproxy.service #${TMP_LOC}/nocloud/files/etc/systemd/system/wssocks.service

# GENERATE N CLIENT CERTIFICATES IN THE CA FOLDER AND THEN PUSH THEM TO OPENVPN
rm -f /tmp/client_template.conf
cat <<EOF >/tmp/client_template.conf
client
dev tun
proto tcp-client
# socks-proxy will always be 169.254.2.2:1111 where the socks5 proxy side of the websockets bridge is.
socks-proxy 169.254.2.2 1111
# remote server will always be the other side of the socks5->websockets bridge port 1194
remote 127.0.0.1 1194
nobind
persist-key
persist-tun
cipher AES-256-CBC
auth SHA256
route 169.254.100.0 255.255.255.0
ping-exit 120
script-security 2
up /etc/openvpn/up.sh
EOF

cd easy-rsa-ca/
rm pki/reqs/${OPNAME}_client${i}.req
# TODO: there's only one client, and all clients right now go on all jumpbox images
# TODO: create one iso for each expected client.
for i in $(seq 1 $CLIENTS)
do
    #mkdir -p clients/${OPNAME}_client${i}
    mkdir -p $JUMPBOX_LOC/root/etc/openvpn/client/
    EASYRSA_REQ_CN="${OPNAME}_client${i}" ./easyrsa gen-req ${OPNAME}_client${i} nopass
    #./easyrsa import-req pki/reqs/${OPNAME}_client${i}.req ${OPNAME}_client${i}
    ./easyrsa sign-req client ${OPNAME}_client${i}
    cp $CUR_LOC/easy-rsa-ca/pki/ca.crt $JUMPBOX_LOC/root/etc/openvpn/client/ca.crt
    cp $CUR_LOC/easy-rsa-ca/pki/issued/${OPNAME}_client$i.crt $JUMPBOX_LOC/root/etc/openvpn/client/client$i.crt
    cp $CUR_LOC/easy-rsa-ca/pki/private/${OPNAME}_client$i.key $JUMPBOX_LOC/root/etc/openvpn/client/client$i.key
    cp $CUR_LOC/server/ta.key $JUMPBOX_LOC/root/etc/openvpn/client/ta.key
    #cp /tmp/client_template.conf /opt/client_configs/client$i/client.conf

    KEY_DIR=$JUMPBOX_LOC/root/etc/openvpn/client/
    cat /tmp/client_template.conf \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/client$i.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/client$i.key \
    <(echo -e '</key>\n<tls-crypt>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-crypt>') \
    > $JUMPBOX_LOC/root/etc/openvpn/client.conf

    # TODO: When we're creating jumpboxes, there really should only be one jumpbox per IP/whatever.
    # if we're doing more than this, we need to think about opsec differently, because discovery of one JB could uncover all
    # so I would lean towards 1 per IP.
    
    #cp $JUMPBOX_LOC/client_configs/client$i/client$i.ovpn $CUR_LOC/jumpbox_files/etc/openvpn/client.ovpn
    # clean up extraneous files
    #rm -rf $JUMPBOX_LOC/client_configs/client$i
done
 
cp -r $JUMPBOX_LOC/root $TMP_LOC/nocloud/files/

# remove existing cloud-init junk we don't want.
rm $TMP_LOC/user-data*
rm $TMP_LOC/meta-data*

sed -i 's/$/ autoinstall ds=nocloud;s=\/boot\/firmware\/nocloud\//' ${TMP_LOC}/cmdline.txt

losetup -d $LOOP_DEVICE
umount $TMP_LOC/

#./rpiboot
#
# wait for the device to appear.
#
# dd if=jumpboxes/ENGAGEMENT_NAME/raspi.img of=/dev/sdX
# sync
#
# unplug the jumpbox, then plug it into internet / monitor to run its setup.
#
# You're done.
