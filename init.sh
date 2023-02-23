#!/bin/bash
# TODO: check to make sure init.sh is in the current folder first.

CUR_LOC=`pwd`

# Download the Pi Image.
wget https://cdimage.ubuntu.com/releases/22.04.1/release/ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz
unxz ubuntu-22.04.1-preinstalled-server-arm64+raspi.img.xz

# create the ca and openvpn easyrsa folders and copy in easyrsa
mkdir easy-rsa-ca/
mkdir easy-rsa-openvpn/
cp -r /usr/share/easy-rsa/* easy-rsa-ca/
cp -r /usr/share/easy-rsa/* easy-rsa-openvpn/

# create the vars for easy-rsa-ca
cat <<EOF >> easy-rsa-ca/vars
set_var EASYRSA_BATCH "yes"
set_var EASYRSA_REQ_COUNTRY    ""
set_var EASYRSA_REQ_PROVINCE   ""
set_var EASYRSA_REQ_CITY       ""
set_var EASYRSA_REQ_ORG        ""
set_var EASYRSA_REQ_EMAIL      ""
set_var EASYRSA_REQ_OU         ""
set_var EASYRSA_ALGO "ec"
set_var EASYRSA_DIGEST "sha512"
set_var EASYRSA_REQ_CN "snakeoil"
EOF

# change to the rsa-ca and build the CA
cd easy-rsa-ca
./easyrsa init-pki
./easyrsa build-ca nopass

# create an openvpn server certificate, change to that dir, create the server keys
mkdir $CUR_LOC/easy-rsa-openvpn
cat <<EOF >> $CUR_LOC/easy-rsa-openvpn/vars
set_var EASYRSA_BATCH          "yes"
set_var EASYRSA_REQ_COUNTRY    "XY"
set_var EASYRSA_REQ_PROVINCE   "Snake Desert"
set_var EASYRSA_REQ_CITY       "Snake Town"
set_var EASYRSA_REQ_ORG        "Snake Oil, Ltd"
set_var EASYRSA_REQ_EMAIL      ""
set_var EASYRSA_REQ_OU         "Certificate Authority"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"
set_var EASYRSA_REQ_CN         "www.snakeoil.dom"
EOF
cd $CUR_LOC/easy-rsa-openvpn/
./easyrsa init-pki
./easyrsa gen-req server nopass

# create the ta key in the openvpn server dir
openvpn --genkey --secret ta.key

# import the server signing request to the certificate authority side
cd $CUR_LOC/easy-rsa-ca
./easyrsa import-req $CUR_LOC/easy-rsa-openvpn/pki/reqs/server.req server
./easyrsa sign-req server server

# return to original dir and copy built keys to server config
cd $CUR_LOC
cp easy-rsa-ca/pki/issued/server.crt server/
cp easy-rsa-ca/pki/ca.crt server/
cp easy-rsa-openvpn/pki/private/server.key server/
cp easy-rsa-openvpn/ta.key server/

