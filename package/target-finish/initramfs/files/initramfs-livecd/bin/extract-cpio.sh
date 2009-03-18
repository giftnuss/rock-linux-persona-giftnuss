#!/bin/sh

file="$1"
[ -z "$file" ] && mount /dev/hdc /media
[ -z "$file" ] && file="$( ls /media/TRUNK*/system.gz )"

[ -e "$file" ] || { "$file does not exist!" ; exit 1 ; }

cpiodir="/branch/$( basename $file )"

if [ "$2" == "dump-irfs" ] ; then
	cpiodir=/real-root
fi

mkdir -p "$cpiodir" || { echo "can't mkdir $cpiodir!" ; exit 1 ; }

mount -t tmpfs tmpfs "$cpiodir" || { echo "can't mount tmpfs on $cpiodir!" ; exit 1 ; }
chmod 0700 "$cpiodir"

gzip -dc "$file" | { cd "$cpiodir" ; cpio -i -d -H newc --no-absolute-filenames ; }

if [ "$2" == "dump-irfs" ] ; then
	mount -t aufs aufs "$cpiodir" -o br:"$cpiodir"=rw
else
	mount / -o remount,append:"$cpiodir"=ro
fi