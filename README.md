First-Time Setup
================
This project assumes you're using the Icebreaker "cooking server" OpenVPN service behind Cloudfront.

1. Get the OVPN CA Key, CA Key decryption passphrase, and ta.key file from Dashlane
2. Copy the CA key to easyrsa-ca/pki/private/ca.key
3. Copy the ta.key to server/ta.key

You may now run setup-jumpbox.sh.  Refer to "Usage" section below for details.


Usage
======

1. Flip over the Jumpbox and remove the four screws from the case.  Remove the case and then pull the Pi's board out from the enclosure carefully by sliding it a bit to the side of the case with no IO ports so that the board comes out smoothly.

2. Orient the board such that the IO ports are facing *away* from you and then look at the bottom right-hand side of the board.  You will see three pins labled (from top to bottom) BOOT, GND, and PWR.

3. Jumper the BOOT and GND pins together with anything handy, and (while still jumping these pins) plug in a USB-C cable to the Pi, with the other side connected to the computer which will build the Pi software.

4. Run the `rpiboot` binary in the "utils" folder of this project to place the Pi into a mode where it exposes its eMMC drive as a storage device.

5. Confirm that the Pi is detected by running `dmesg` or similar utilities.  Note the drive designation (e.g. /dev/sda) 

6. Generate the jumpbox image with the instructions below:
```
# Generate the jumpbox image
sudo ./setup-jumpbox.sh TEST_PI chevychasetrusts.com ubuntu-22.04.1-preinstalled-server-arm64+raspi.img

# Plug in the Raspi CM4 board via the USBC port while the BOOT and GND pins are jumpered.
sudo /utils/rpiboot

# copy the image to the Pi once /dev/sdX has appeared, where X is replaced with the actual block device designation
sudo dd if=jumpboes/TEST_PI/raspi.img of=/dev/sdX

# ensure no buffered writes remain
sudo sync

# unmount any mounted partitions (on linux usually /dev/sda1 will auto-mount)
umount /dev/sda1
```

7. Complete the setup by following the "First Boot Instructions" below.


First Boot Instructions
=======================

The first time the Pi boots, it needs to run the cloud-init procedure which will setup the Pi according to the cloud-init recipe (defined in this project).  This mode of configuration is useful because it ensures a jumpbox is standardized, up-to-date, and has certain runtime-generated settings applied properly (e.g. NTP).

0. Put the Pi back into it's housing.  This is important because the housing contains a heatsink for the Raspberry Pi, which will become overheated quickly without it.

1. Unplug the USB cable, plug in the network cable to the network jack closest to the USB port bank, and plug in a monitor before re-applying power via the USB cable.

2. The Pi will boot.  It may take a significant amount of time, but eventually you will see it hit the CLI login prompt and shortly after that will begin running the final cloud-init modules.

3. The Pi will shut down when it is done, which will not be outwardly noticable in any way except that the monitor will stop displaying anything.

4. Unplug the USB-C cable and re-plug it in, then confirm that the Pi is connecting to the OpenVPN server as expected.

Congratulations! The Pi Jumpbox is ready to ship to another happy customer.
