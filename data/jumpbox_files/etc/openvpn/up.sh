#!/bin/bash

ip route add default via `ip route | grep 'tun0 proto kernel scope link' | awk '{print $9}'`
