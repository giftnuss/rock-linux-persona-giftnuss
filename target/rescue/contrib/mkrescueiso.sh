#!/bin/sh
#
# This is a contributed script to create a bootable ISO image from your
# rescue target build.
#
# It uses grub with fd-emu to create a bootable image.
#
# (C) 2004 Tobias Hintze
#

GRUBSRC=/usr/share/grub/i386-*
set -e

usage() {
	echo "Usage:"
	echo "  $0 ISODIR FDDIR"
	echo "       creates the iso image from iso-dir and fd-dir"
	echo
	echo "  $0 -c KERNEL INITRD[.gz] SYSTEM [OVERLAY]"
	echo "       creates iso-dir and fd-dir"
	echo
	echo "  $0 -C KERNEL INITRD[.gz] SYSTEM [OVERLAY]"
	echo "       creates the iso image from kernel, initrd and system tarball"
	echo ""
	echo "Example usage (most commonly used):"
	echo "(You get an iso image with default configuration and given files.)"
	echo ""
	echo "$0 -C vmlinuz initrd.img system.tar.bz2"
	echo ""
	echo "Using the -C option is like using the -c option except that after creating"
	echo "the temporary directories the script calls itself to create the image from them"
	echo "(first usage option). The directories are deleted on success afterwards."
	echo ""
	echo "* initrd.img and system.tar.bz2 are generated during the rescue-target build."
	echo "* kernel must have support for devfs"
	echo "* kernel must have support for initrd"
	echo "* kernel must have support for iso9660"
	echo "* kernel must be small to fit on 2880KB (minus initrd and grub stages)"
	exit 1
}

die() {
	echo "$1"
	exit 2
}

check_reqs() {
	[ -z "`type -p e2fsimage`" ] && \
		die "You need e2fsimage to create an image with this script."
	[ -z "`type -p mkisofs`" ] && \
		die "You need mkisofs to create an image with this script."
	[ -z "`type -p grub`" ] && \
		die "You need grub to create an image with this script."
	echo "requirements ok."
}

test -z "$1" && usage
case "$1" in
	-c|-C)
		CREATEDIRS=1
		[[ "$1" == "-C" ]] && CREATEDIRS=2
		[[ $# == 4 || $# == 5 ]] || usage
		[ -r $2 ] || exec echo "failed to read kernel image $2"
		[ -r $3 ] || exec echo "failed to read initrd image $3"
		[ -r $4 ] || exec echo "failed to read system $4"
		[[ $# == 5 ]] && {
			[ -r $5 ] || exec echo "failed to read overlay $5"
		}
		;;
	*)
		[[ $# == 2 ]] || usage
		[ -r $1 ] || exec echo "failed to read iso-dir $1"
		[ -r $2 ] || exec echo "failed to read fd-dir $2"
		;;
esac

[[ "$CREATEDIRS" != 1 ]] && [ -e iso ] && die "file \"iso\" is in my way."

check_reqs

if [ -n "$CREATEDIRS" ]
then
	shift
	TMPDIR=/var/tmp/rescue.$$
	mkdir $TMPDIR || die "failed to create tmp-dir \"$TMPDIR\"."
	mkdir -v $TMPDIR/iso $TMPDIR/fd

	#
	# prepare fd dir
	#
	test -z "$1" && usage
	KERNEL=$1 ; shift
	test -z "$1" && usage
	INITRD=$1 ; shift
	test -z "$1" && usage
	SYSTEM=$1 ; shift

	# kernel to fd
	cp -v $KERNEL $TMPDIR/fd/bzImage

	# initrd to fd
	if [ "`file -bi $INITRD`" == "application/x-gzip" ] ; then
		cp -v $INITRD $TMPDIR/fd/initrd.gz
	else
		echo "compressing initrd image..."
		cat $INITRD | gzip -c > $TMPDIR/fd/initrd.gz
	fi

	mkdir $TMPDIR/fd/grub
	# menu.lst to fd
	cat > $TMPDIR/fd/grub/menu.lst << EOF
timeout 10
title rescue ramdisk from cdrom
kernel (fd0)/bzImage root=/dev/ram0 boot=iso9660:/dev/cdroms/cdrom0 panic=30
initrd (fd0)/initrd.gz

title LVM-boot-cycle
configfile (fd0)/grub/menu.lst-LBC
EOF
	cat > $TMPDIR/fd/grub/menu.lst-LBC << EOF

title lvm boot cycle rootlv=/dev/vg00/lvroot0
kernel (fd0)/bzImage root=/dev/ram0 boot=iso9660:/dev/cdroms/cdrom0 stage2init=/sbin/init-lvm-cycle rootlv=/dev/vg00/lvroot0 panic=30
initrd (fd0)/initrd.gz

title lvm boot cycle rootlv=/dev/vg00/lvroot1
kernel (fd0)/bzImage root=/dev/ram0 boot=iso9660:/dev/cdroms/cdrom0 stage2init=/sbin/init-lvm-cycle rootlv=/dev/vg00/lvroot1 panic=30
initrd (fd0)/initrd.gz

title lvm boot cycle rootlv=/dev/vg00/lv00
kernel (fd0)/bzImage root=/dev/ram0 boot=iso9660:/dev/cdroms/cdrom0 stage2init=/sbin/init-lvm-cycle rootlv=/dev/vg00/lv00 panic=30
initrd (fd0)/initrd.gz
EOF
	cp -v $GRUBSRC/stage[12] $GRUBSRC/{e2fs,fat,xfs}_stage1_5 $TMPDIR/fd/grub/

	#
	# prepare iso dir
	#
	mkdir $TMPDIR/iso/rescue/
	cp -v $SYSTEM $TMPDIR/iso/rescue/system.tar.bz2

	if [ ! -z "$1" ] ; then
		OVERLAY=$1 ; shift
		cp -v $OVERLAY $TMPDIR/iso/rescue/overlay.tar.bz2
	fi

	if [ "$CREATEDIRS" == "1" ] ; then
		echo "ready. you might want to run:"
		echo "$0 $TMPDIR/iso $TMPDIR/fd"
	elif [ "$CREATEDIRS" == "2" ] ; then
		echo "running $0 $TMPDIR/iso $TMPDIR/fd"
		$0 $TMPDIR/iso $TMPDIR/fd
		rm -rfv $TMPDIR/iso $TMPDIR/fd
		rmdir -v $TMPDIR
	fi
	exit 0
fi

ISODIR=$1 ; shift

test -z "$1" && usage
FDDIR=$1 ; shift

test -d $ISODIR || die "ISODIR \"$ISODIR\" not a directory."
test -d $FDDIR || die "FDDIR \"$FDDIR\" not a directory."

e2fsimage -f $ISODIR/fdemu.img -d $FDDIR -v -s 2880
rm -f $ISODIR/device.map-$$
echo "(fd0) $ISODIR/fdemu.img" > $ISODIR/device.map-$$
if [ "`id -u`" == "0" ]
then
	die "i don't want to run grub as root. destructive potential too high."
fi
grub --device-map=$ISODIR/device.map-$$ --batch <<EOF
root (fd0)
setup (fd0)
EOF
rm -fv $ISODIR/device.map-$$


create_iso_image() {
	test -e iso && die "file \"iso\" is in my way."
	mkisofs -b fdemu.img -r -l -d -c boot.catalog \
		-allow-multidot -allow-lowercase -o iso $ISODIR
}

create_iso_image
