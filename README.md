First-Time Setup
================
This project assumes you're using the Icebreaker "cooking server" OpenVPN service behind Cloudfront.

1. Get the OVPN CA Key, CA Key decryption passphrase, and ta.key file from Dashlane
2. Copy the CA key to easyrsa-ca/pki/private/ca.key
3. Copy the ta.key to server/ta.key

You may now run setup-jumpbox.sh.  Refer to "Usage" section below for details.



Usage
======
```
# Generate the jumpbox image
./setup-jumpbox.sh TEST_PI chevychasetrusts.com ubuntu-22.04.1-preinstalled-server-arm64+raspi.img

# Plug in the Raspi CM4 board via the USBC port while the BOOT and GND pins are jumpered.
/utils/rpiboot

# copy the image to the Pi once /dev/sdX has appeared, where X is replaced with the actual block device designation
dd if=jumpboes/TEST_PI/raspi.img of=/dev/sdX

# ensure no buffered writes remain
sync
```

Once the above is complete, you may disconnect the USB-C cable and boot the Pi.  BEFORE BOOTING THE PI, ENSURE THAT THE NETWORK CABLE IS PLUGGED INTO THE NETWORK PORT CLOSEST TO THE BANK OF 2 USB PORTS (the right hand side if you are viewing the ports head-on).  The Pi will boot and then begin setup shortly after it reaches the log-in prompt.  Do not disturb the pi.
