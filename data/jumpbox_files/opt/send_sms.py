#!/usr/bin/python3

#####################################################################
#                    send_sms.py                                    #
#                                                                   #
#  Uses the ZTE MF833V's built-in webserver to send a text message  #
#                                                                   #
#####################################################################

import datetime
import pdb
import urllib
import urllib.request
import urllib.parse
import sys
import binascii
import json

def send_sms(phonenum:str, message:str):
    if len(message) > 765:
        raise Exception("MessageTooLong")

    headers = {
        "Origin":"http://192.168.0.1",
        "Referer":"http://192.168.0.1/index.html",
        "Content-Type":"application/x-www-form-urlencoded; charset=UTF-8",
        "X-Requested-With":"XMLHttpRequest"
    }

    messagebody = binascii.hexlify(message.encode("utf-16-be")).decode("utf-8")
    params={
        "isTest":False,
        "goformId":"SEND_SMS",
        "notCallback":True,
        "Number":phonenum,
        "sms_time":datetime.date.today().strftime("%y;%m;%d;%H;%M;%S;%z"),
        "MessageBody":messagebody,
        "ID":"-1",
        "encode_type": "GSM7_default"
    }
    params = urllib.parse.urlencode(params).encode()

    resp = None
    try:
        req = urllib.request.Request("http://192.168.0.1/goform/goform_set_cmd_process", params, headers, method="POST")
        resp = urllib.request.urlopen(req)
        resp = json.loads(resp.read())
    except Exception as error:
        print("ERR")

    if resp is not None and resp['result'] == "success":
        return True
    else:
        return False

if __name__ == "__main__":
    phonenum = sys.argv[1]
    message = sys.argv[2]
    try:
        send_sms(phonenum,message)
    except Exception as error:
        print("! ERROR ! - %s" % (error))
        sys.exit(1)