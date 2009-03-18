#!/bin/bash

echo "DEVICE partitions" > /etc/mdadm.conf
echo "MAIL root@localhost" >> /etc/mdadm.conf

/sbin/mdadm -Ebsc partitions >> /etc/mdadm.conf
