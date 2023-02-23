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

logging.basicConfig(
    level=logging.DEBUG,
    format="[%(asctime)s]:[%(levelname)s]: %(message)s",
    handlers=[
        logging.FileHandler('/var/log/connection_monitor.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logging.debug('The connection monitor script was called')

# todo - class needs a logger internally otherwise good luck calling it outside this "package"

LTE_IFACE="usb0"
LTE_GW="192.168.0.1"
MIN_UPTIME_SEC = 90 # time that must pass from boot before attempting a check of the LTE interface for an IP address from the ISP
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
    req = urllib.request.Request("http://192.168.0.1/goform/goform_get_cmd_process?multi_data=1&isTest=false&sms_received_flag_flag=0&sts_received_flag_flag=0&cmd=wan_ipaddr%2Cipv6_wan_ipaddr%2Cwan_connect_status", data=None, headers={"Referer":"http://192.168.0.1/index.html"})
    response_object = None
    try:
        res = urllib.request.urlopen(req, timeout=1)
        response_object = json.loads(res.read())

    # Handle situation where the dongle is not present and we timeout
    except urllib.error.URLError as error:
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

import sys, os, time, atexit
from signal import SIGTERM

class Daemon:
        """
        A generic daemon class.

        Usage: subclass the Daemon class and override the run() method
        """
        def __init__(self, pidfile, isdaemon=True, stdin='/dev/null', stdout='/dev/null', stderr='/dev/null'):
                self.stdin = stdin
                self.stdout = stdout
                self.stderr = stderr
                self.pidfile = pidfile
                self.isdaemon = isdaemon

        def daemonize(self):
                """
                do the UNIX double-fork magic, see Stevens' "Advanced
                Programming in the UNIX Environment" for details (ISBN 0201563177)
                http://www.erlenstar.demon.co.uk/unix/faq_2.html#SEC16
                """

                # if we aren't set to daemonize, just skip
                # this is really useful for debugging.
                if self.isdaemon is False:
                    return

                try:
                        pid = os.fork()
                        if pid > 0:
                                # exit first parent
                                sys.exit(0)
                except OSError as e:
                        sys.stderr.write("fork #1 failed: %d (%s)\n" % (e.errno, e.strerror))
                        sys.exit(1)

                # decouple from parent environment
                os.chdir("/")
                os.setsid()
                os.umask(0)

                # do second fork
                try:
                        pid = os.fork()
                        if pid > 0:
                                # exit from second parent
                                sys.exit(0)
                except OSError as e:
                        sys.stderr.write("fork #2 failed: %d (%s)\n" % (e.errno, e.strerror))
                        sys.exit(1)

                # redirect standard file descriptors
                sys.stdout.flush()
                sys.stderr.flush()
                si = open(self.stdin, 'r')
                so = open(self.stdout, 'a+')
                se = open(self.stderr, 'ab+', 0)
                os.dup2(si.fileno(), sys.stdin.fileno())
                os.dup2(so.fileno(), sys.stdout.fileno())
                os.dup2(se.fileno(), sys.stderr.fileno())

                # write pidfile
                atexit.register(self.delpid)
                pid = str(os.getpid())
                open(self.pidfile,'w+').write("%s\n" % pid)

        def delpid(self):
                os.remove(self.pidfile)

        def start(self):
                """
                Start the daemon
                """
                # Check for a pidfile to see if the daemon already runs
                try:
                        pf = open(self.pidfile,'r')
                        pid = int(pf.read().strip())
                        pf.close()
                except IOError:
                        pid = None

                if pid:
                        message = "pidfile %s already exist. Daemon already running?\n"
                        sys.stderr.write(message % self.pidfile)
                        sys.exit(1)

                # Start the daemon
                self.daemonize()
                self.run()

        def stop(self):
                """
                Stop the daemon
                """
                # Get the pid from the pidfile
                try:
                        pf = open(self.pidfile,'r')
                        pid = int(pf.read().strip())
                        pf.close()
                except IOError:
                        pid = None

                if not pid:
                        message = "pidfile %s does not exist. Daemon not running?\n"
                        sys.stderr.write(message % self.pidfile)
                        return # not an error in a restart

                # Try killing the daemon process       
                try:
                        while 1:
                                os.kill(pid, SIGTERM)
                                time.sleep(0.1)
                except OSError as err:
                        err = str(err)
                        if err.find("No such process") > 0:
                                if os.path.exists(self.pidfile):
                                        os.remove(self.pidfile)
                        else:
                                print(str(err))
                                sys.exit(1)

        def restart(self):
                """
                Restart the daemon
                """
                self.stop()
                self.start()

        def run(self):
                """
                You should override this method when you subclass Daemon. It will be called after the process has been
                daemonized by start() or restart().
                """
                pass

class ConnectionMonitor(Daemon):
    def __init__(self, isdaemon = True):
        pidfile = "/tmp/connection_monitor.pid"
        super().__init__(pidfile, isdaemon)
        self.recovery_mode_enabled = False

    # things to do if we lost connectivity
    def recovery_mode(self, enable):
        # don't do anything if we're not changing any state.
        if self.recovery_mode_enabled == enable:
            return enable

        if enable:
            logging.critical("ENABLING RECOVERY MODE")
            #os.system("systemctl stop openvpn@client")
            #command = "ip netns exec customer nohup openvpn --daemon --config /etc/openvpn/client.conf"
            command = "bash -x /opt/route.sh 2>&1 | tee -a /var/log/route.log"
            subprocess.Popen(command,
                    stdout=None, #open('/dev/null', 'w'),
                    stderr=None, #open('/var/log/openvpn_recovery.log', 'a'),
                    preexec_fn=os.setpgrp,
                    shell=True
                    )
            logging.debug("RECOVERY MODE ENABLED")
        else:
            logging.debug("RETURNING TO NORMAL OPERATIONS MODE")
            os.system("ip link del tocustomer")
            logging.debug("NORMAL OPERATIONS ENABLED")
        self.recovery_mode_enabled = enable
        return enable

    def run(self):
        # if the system is still fresh from booting, wait.  The LTE dongle may not have a lock yet.
        uptime = get_uptime()
        
        if uptime < MIN_UPTIME_SEC:
            wait_period = MIN_UPTIME_SEC - uptime
            logging.warning("LTE connection monitor waiting for %d seconds to meet MIN_UPTIME requirements prior to checking LTE status" % (wait_period))
            time.sleep(wait_period)

        # if there's no detection of the LTE interface at boot, we don't have it, just exit.
        if detect_iface(LTE_IFACE) == False:
            self.recovery_mode(True)
            #sys.exit(1)


        # disconnections = [ int(timestamp_in_epoch_seconds) ]
        disconnections = []
        ovpn_disconnection_time = None
        while 1:
            try:
                if not self.recovery_mode_enabled:
                    # is the iface present? Required for any followon checks.
                    if detect_iface(LTE_IFACE) == False:
                        # TODO: do we want to reboot if we used to have the LTE interface and now we don't have it?
                        self.recovery_mode(True)

                    # is the iface up? Required for any followon checks.
                    if get_operstate(LTE_IFACE) == False:
                        bounce_iface(LTE_IFACE)
                        continue

	                # does the iface report LTE connections?
                    connection_state = get_connection_state()
	                
                    if connection_state == LTEConnStatus.UNKNOWN:
                        logging.debug("LTE UNKNOWN state")
                        disconnections.append(int(time.time()))
                        bounce_iface(LTE_IFACE)

                    elif connection_state == LTEConnStatus.DISCONNECTED:
                        logging.debug("LTE DISCONNECTED state")
                        disconnections.append(int(time.time()))

                    elif connection_state == LTEConnStatus.CONNECTED:
                        logging.debug("LTE CONNECTED state")
	                    

                    # remove items from the list as we are processing it
                    logging.debug("aggregating disconnection events")
                    disconnections_count = 0
                    q = len(disconnections)-1
                    z = 0
                    while z < q:            
                        if (int(time.time()) - disconnections[z]) > CONNECTION_MONITOR_PERIOD:
                            disconnections.remove(z)
                            q = q - 1
                            continue
                        else:        
                            z += 1
                            disconnections_count += 1
                    logging.debug("logging.debug done aggregation")
                    if disconnections_count >= MAX_CONNECTION_LOSS_EVENTS:
                        logging.debug("Too many disconnection events within monitoring period, falling back to recovery mode")
                        self.recovery_mode(True)    
                # check that we can reach the outside world at all.
                # right now we assume that if tun0 is up, that it's a solid connection to openvpn
                if not detect_iface(OVPN_INTERFACE):
                    logging.critical("OpenVPN interface not detected at %d" % (time.time()))
                    if ovpn_disconnection_time is None:
                        ovpn_disconnection_time = time.time()
                    if (time.time() - ovpn_disconnection_time) > MAX_DISCONNECTION_TIME:
                        logging.critical("[!] Jumpbox was disconnected for over %d seconds, rebooting!" % (MAX_DISCONNECTION_TIME))
                        os.system("init 6")
                else:
                    if ovpn_disconnection_time is not None:
                        logging.warning("OVPN reconnected after %d seconds of disconnection" % (time.time()-ovpn_disconnection_time))        
                        ovpn_disconnection_time = None
                logging.debug("loop completed, sleeping 60 seconds")
                time.sleep(6)
            except Exception as err:
                logging.critical(err)
                
# this is done to prevent module from running on import during testing
if __name__ == "__main__":
    # if this is called with ./connection_monitor.py debug it will run in the foreground allowing you to insert pdb.set_trace() breakpoints to debug
    isdaemon = True
    if len(sys.argv) > 1 and sys.argv[1].lower() == "debug":
        isdaemon = False
    connmonitor = ConnectionMonitor(isdaemon=isdaemon)
    connmonitor.start()
