#!/bin/bash

cp /lib/systemd/system/dhcrelay.service /etc/systemd/system
chmod +w /etc/systemd/system/dhcrelay.service

echo "Nhập địa chỉ của DHCP Server"
read DHCP_SERVERIP
NEWLINE="ExecStart=/usr/sbin/dhcrelay -d --no-pid $DHCP_SERVERIP"
sed -i "9s#.*#$NEWLINE#" /etc/systemd/system/dhcrelay.service

systemctl --system daemon-reload
systemctl start dhcrelay.service

