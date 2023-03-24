#!/usr/bin/python3
import json
from sqlite3 import connect
import urllib
import urllib.request
import sys
import math
import socket
import pathlib
import os
import io
import time
from enum import Enum
import logging
import subprocess

logging.basicConfig()
# todo - class needs a logger internally otherwise good luck calling it outside this "package"

LTE_IFACE="usb0"
LTE_GW="192.168.0.1"
MIN_UPTIME_SEC = 60 # time that must pass from boot before attempting a check of the LTE interface for an IP address from the ISP
CONNECTION_MONITOR_PERIOD=(5*60) # in seconds
MAX_CONNECTION_LOSS_EVENTS=2

# failsafe vars
MAX_DISCONNECTION_TIME = 60
FAILSAFE_COUNTDOWN="/tmp/failsafe_countdown"
OVPN_INTERFACE="tun0"

class LTEConnStatus(Enum):
    CONNECTED = 0
    DISCONNECTED = 1
    BOOTING = 2
    UNKNOWN = 3
    MISSING = 4
    ERROR = 5

def get_operstate(iface):
    try:
        fp = open("/sys/class/net/%s/operstate" % (iface),'r')
        operstatus = fp.read().strip()
        logging.debug("operstatus of %s is %s" % (iface, operstatus))
        fp.close()
    # if the iface isn't found it won't have the file, so this is thrown and caught.
    except FileNotFoundError:
        return False
    except Exception as err:
        logging.critical(err)
        return False

    if operstatus == "down":
        return False
    return True

def detect_iface(iface):
    # not present
    if not pathlib.Path("/sys/class/net/%s/" % (iface)).exists():
        logging.warning("detect_iface did not detect %s" % (iface))
        return False
    return True

def get_connection_state():
    if not detect_iface("usb0"):
        return LTEConnStatus.MISSING
    req = urllib.request.Request("http://192.168.0.1/goform/goform_get_cmd_process?multi_data=1&isTest=false&sms_received_flag_flag=0&sts_received_flag_flag=0&cmd=wan_ipaddr%2Cipv6_wan_ipaddr%2Cwan_connect_status", data=None, headers={"Referer":"http://192.168.0.1/index.html"})
    response_object = None
    try:
        res = urllib.request.urlopen(req, timeout=1)
        response_object = json.loads(res.read())

        #print(response_object)
    # Handle situation where the dongle is not present and we timeout
    except urllib.error.URLError as error:
        print(error)
        if isinstance(error.reason, socket.timeout):
            logging.debug("LTE get_connection_state: UNKNOWN")
            return LTEConnStatus.UNKNOWN
            # recommend bounce LTE interface and retry the connection check.

    #example:
    #{'wan_ipaddr': '26.160.228.177', 'ipv6_wan_ipaddr': '2607:fb90:a904:df72:406f:09de:8f48:5a55', 'wan_connect_status': 'pdp_connected'}

    # this occurs when the interface is present, but unconfigured or damaged, so should be handled.
    if response_object is None:
        return LTEConnStatus.UNKNOWN

    # going into this logic means that the LTE connection is lost / degraded and we probably want to monitor that to make sure it's not frequently down for short periods nor down for long periods
    if (response_object['wan_ipaddr'] == "" and response_object['ipv6_wan_ipaddr'] == "" ) or (response_object['wan_connect_status'] != 'pdp_connected'):
        logging.debug("LTE get_connection_state: DISCONNECTED")
        return LTEConnStatus.DISCONNECTED

    # everything is fine.
    else:
        logging.debug("connected")
        return LTEConnStatus.CONNECTED

def bounce_iface(iface):
    logging.debug("bouncing the LTE Interface")
    os.system("ip link set %s up" % (iface))
    time.sleep(1)
    os.system("ip link set %s up" % (iface))
    time.sleep(1)

def get_uptime():
    fp = open('/proc/uptime','r')
    uptime = fp.read()
    fp.close()
    uptime = uptime.split(" ")[0]
    uptime = float(uptime)
    uptime = int(uptime)
    return uptime

# this is done to prevent module from running on import during testing
if __name__ == "__main__":
    if len(sys.argv)>1 and sys.argv[1].lower() == "get_connection_state":

        try:
            connstate = get_connection_state()
            while get_uptime() < MIN_UPTIME_SEC:
                if connstate == LTEConnStatus.CONNECTED:
                    break
                time.sleep(1)
                connstate = get_connection_state()

        except Exception as err:
            connstate = LTEConnStatus.ERROR

        finally:
            print(connstate.name)
            sys.exit(connstate.value)