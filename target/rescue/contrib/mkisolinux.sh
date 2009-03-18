#!/bin/sh
#
# This is a contributed script to create a bootable ISO image from your
# rescue target build.
#
# It uses isolinux (syslinux) to create a non-emu bootable image.
# It uses memdisk (syslinux) to add grub to the list of choices.
#
# (C) 2004 Tobias Hintze
#

[ -z "$GRUBSRC" ] && GRUBSRC="/usr/share/grub"
[ -z "$SYSLINUXSRC" ] && SYSLINUXSRC="/usr/lib/syslinux"

set -e

usage() {
	echo "Usage:"
	echo "  $0 ISODIR"
	echo "       creates the iso image from iso-dir"
	echo
	echo "  $0 -c KERNEL INITRD[.gz] SYSTEM [OVERLAY]"
	echo "       creates iso-dir"
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
	echo "the temporary iso-dir the script calls itself to create the image from that"
	echo "dir (first usage option). The iso-dir is deleted on success afterwards."
	echo ""
	echo "* initrd.img and system.tar.bz2 are generated during the rescue-target build."
	echo "* kernel must have support for devfs"
	echo "* kernel must have support for initrd"
	echo "* kernel must have support for iso9660"
	echo ""
	exit 1
}

die() {
	echo "$1"
	exit 2
}

check_reqs() {
	[ -z "`type -p grub`" ] && \
		die "You need grub to create an image with this script."
	[ -z "`type -p e2fsimage`" ] && \
		die "You need e2fsimage to create an image with this script."
	[ -z "`type -p mkisofs`" ] && \
		die "You need mkisofs to create an image with this script."
	[ -d "$GRUBSRC" ] || die "No grub stages at $GRUBSRC. I need them!"
	[ -d "$SYSLINUXSRC" ] || die "No syslinux at $SYSLINUXSRC. I need it!"
	echo "requirements ok."
}


test -z "$1" && usage
case "$1" in
	-c|-C)
		CREATEDIR=1
		[[ "$1" == "-C" ]] && CREATEDIR=2
		[[ $# == 4 || $# == 5 ]] || usage
		[ -r $2 ] || exec echo "failed to read kernel image $2"
		[ -r $3 ] || exec echo "failed to read initrd image $3"
		[ -r $4 ] || exec echo "failed to read system $4"
		KERNEL=$2
		INITRD=$3
		SYSTEM=$4

		[[ $# == 5 ]] && {
			[ -r $5 ] || exec echo "failed to read overlay $5"
			OVERLAY=$5
		}
		;;
	*)
		[[ $# == 1 ]] || usage
		[ -r $1 ] || exec echo "failed to read iso-dir $1"
esac

[[ "$CREATEDIR" != 1 ]] && [ -e iso ] && die "file \"iso\" is in my way."

check_reqs

GRUBSRC="$( find $GRUBSRC -type d -mindepth 1 -maxdepth 1 | head -n 1 )"
[ -r $GRUBSRC/stage1 -a -r $GRUBSRC/stage2 ] || die "grub stage1 or stage2 missing."

[	-r $SYSLINUXSRC/isolinux.bin -a \
	-r $SYSLINUXSRC/memdisk ] || die "isolinux.bin or memdisk missing."

if [ -n "$CREATEDIR" ]
then
	TMPDIR=/var/tmp/rescuecd.$$
	mkdir $TMPDIR || die "failed to create tmp-dir \"$TMPDIR\"."
	mkdir -pv $TMPDIR/iso/isolinux $TMPDIR/iso/rescue $TMPDIR/fd

	
	#
	# prepare the directory
	#
	
	# syslinux
	cp -v $SYSLINUXSRC/isolinux.bin $SYSLINUXSRC/memdisk $TMPDIR/iso/isolinux/

	# kernel
	cp -v $KERNEL $TMPDIR/iso/isolinux/krescue

	# initrd
	if [ "`file -bi $INITRD`" == "application/x-gzip" ] ; then
		cp -v $INITRD $TMPDIR/iso/isolinux/rdrescue.gz
	else
		echo "compressing initrd image..."
		cat $INITRD | gzip -c > $TMPDIR/iso/isolinux/rdrescue.gz
	fi

	cp -v $SYSTEM $TMPDIR/iso/rescue/system.tb2
	[ -n "$OVERLAY" ] && cp -v $OVERLAY $TMPDIR/iso/rescue/overlay.tb2

	#
	# create grub fd
	#
	echo "creating bootable grub fd image"
	mkdir -v $TMPDIR/fd/grub
	cp -v $GRUBSRC/*stage* $TMPDIR/fd/grub/
	e2fsimage -f $TMPDIR/iso/isolinux/fdgrub.img -d $TMPDIR/fd -v -s 360
	rm -f $TMPDIR/device.map
	echo "(fd0) $TMPDIR/iso/isolinux/fdgrub.img" > $TMPDIR/device.map
	[[ "`id -u`" == "0" ]] && {
		echo "i don't want to run grub as root. destructive potential too high."
		echo "if you want to do it on your own issue the following command: "
		echo
		echo "grub --device-map=$TMPDIR/device.map --batch <<EOF"
		echo "root (fd0)"
		echo "setup (fd0)"
		echo "EOF"
		echo
		die "Cowardly refusing to endanger your MBR and disks."
	}
	grub --device-map=$TMPDIR/device.map --batch <<EOF
root (fd0)
setup (fd0)
EOF
	echo ""
	echo "finished creating fdgrub.img"

	# create isolinux.cfg
	cat > $TMPDIR/iso/isolinux/isolinux.cfg << EOF
DEFAULT rescue
TIMEOUT 300
PROMPT 1

DISPLAY display.txt

LABEL rescue
	KERNEL krescue
	APPEND initrd=rdrescue.gz root=/dev/ram boot=iso9660:/dev/cdroms/cdrom0 system=/mnt_boot/rescue/system.tb2 overlay=/mnt_boot/rescue/overlay.tb2 panic=60

LABEL grub
	KERNEL memdisk
	APPEND initrd=fdgrub.img

EOF
	cat > $TMPDIR/iso/isolinux/display.txt << "EOF"

             ____   ___   ___ _  __  _
            |  _ \ / _ \ / __| |/ / | |   _ _ __  _   _ _  _
            | . _/| | | | |  | '_/  | |  |_| '_ \| | | | \/ |
            | |\ \| |_| | |__| . \  | |__| | | | | `_' |>  <
            |_| \_\ ___/ \___|_|\_\ |____|_|_| |_|\___/|_/\_|
         [============> http://www.rocklinux.org/ <============]


Actions:
--------

     <ENTER>                   Boot into rescue system (ramdisk)
     grub <ENTER>              Run grub from emulated floppy image
     rescue options <ENTER>    Boot into rescue system with given options


"EOF"
EOF

	if [ "$CREATEDIR" == "1" ] ; then
		echo "ready. you might want to run:"
		echo "$0 $TMPDIR/iso"
	elif [ "$CREATEDIR" == "2" ] ; then
		echo "running $0 $TMPDIR/iso"
		$0 $TMPDIR/iso
		rm -rfv $TMPDIR
	fi
	exit 0
fi

test -z "$1" && usage
ISODIR=$1

test -d $ISODIR || die "ISODIR \"$ISODIR\" not a directory."

create_iso_image() {
	test -e iso && die "file \"iso\" is in my way."
	mkisofs -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 \
		-boot-info-table -o iso $ISODIR
}

create_iso_image
