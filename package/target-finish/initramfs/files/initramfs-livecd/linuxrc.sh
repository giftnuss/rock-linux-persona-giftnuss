#!/bin/sh
echo "$0: $*"

PATH="/bin:/usr/bin:/sbin:/usr/sbin"
export PATH

[ -z "$autoboot" ] && autoboot=0

if [ "$autoboot" -eq 0 ] ; then
	echo "Interactive stage 1, spawning /bin/bash. Exit to continue booting..."
	/bin/bash
fi

for x in /init.d/*
do
	. $x
done

while : ; do
	echo "going real..."
	if [ -x /real-root/sbin/init ] ; then
		#exec /sbin/run_init /real-root /sbin/init
		
# 		mount --move  /dev /real-root/dev
# 		mount --move  /proc /real-root/proc
# 		mount --move /sys /real-root/sys
		umount -l /dev
		umount -l /proc
		umount -l /sys

		mkdir -p /real-root/branch/irfs
		mount --bind / /real-root/branch/irfs

		cd /real-root
		sed -e "s,/*real-root/*,/,g" /etc/mtab > etc/mtab
		exec chroot . sh -c "exec /sbin/init" <dev/console >dev/console 2>&1
	elif [ -x /sbin/init ] ; then
		exec /sbin/init <dev/console >dev/console 2>&1
	fi
	echo "no /real-root/sbin/init found. spawning /bin/bash..."
	/bin/bash
done
