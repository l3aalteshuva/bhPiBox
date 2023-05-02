#!/usr/bin/python3
import subprocess
import sys
import re
# todo: remove hardcoded password for CCC user
# note that this password isn't exploitable since nobody but VPN users are able to access the nessus web console.
input = b"user\nP@55W0rd!\nP@55W0rd!\ny\n\ny\n"
nessuscli = subprocess.Popen(["/opt/nessus/sbin/nessuscli", "adduser"], stdout=subprocess.PIPE, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
output = nessuscli.communicate(input=input)[0]
if re.search(b"User added", output) is not None:
    sys.exit(nessuscli.returncode)
else:
    print("POSSIBLE ERROR ADDING USER")
    sys.exit(-1)
