#!/bin/sh
# Beside eth0, the eth1 is added for debug and diagnostics.
# eth0 is set to get ip from the dhcp server.
# eth1 is assigned a static ip 169.254.243.73.
echo "set up eth0"
ip link set dev eth0 up
echo "set up lo"
ip link set dev lo up
echo "config addr for lo"
ip address add 127.0.0.1/8 dev lo
echo "set up eth1"
ip link set dev eth1 up

/etc/init.d/networking restart
ifconfig eth0 0.0.0.0 0.0.0.0 && dhclient eth0

echo "set up eth1"
ip link set dev eth1 up
echo "config addr"
ip address add 169.254.243.73/16 dev eth1

echo "show addr"
ip addr
echo "show route"
ip route show
