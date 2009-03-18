#!/bin/sh
#
# this script is to be called by devfsd on REGISTER for cd and generic devs.
#
# corresponding devfsd.conf line should look this way:
# REGISTER ^((ide|scsi)/.*)/(cd|generic)$ EXECUTE /usr/lib/devfsd/cdrom_register.sh $mntpnt \1 \3
#
# [M] Tobias Hintze <th@rocklinux.org>
#
if [ "$#" != "3" ]
then
	logger "$0 called with invalid arguments."
	exit
fi

# secure default
MODE=600
OWNER=root.root

# possible convenience to override MODE and OWNER
[ -r /etc/conf/devfs.cdrom ] && . /etc/conf/devfs.cdrom

if [ -b "$1/$2/cd" ]
then
	# this is a cdrom
	chown $OWNER "$1/$2/$3"
	chmod $MODE "$1/$2/$3"
	logger "permissions for $1/$2/$3 set."
fi

