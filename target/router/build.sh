
pkgloop

echo_header "Creating the router ramdisk..."

echo_status "Creating the directory structure."
outdir="$build_rock/router"
rm -rf $outdir
mkdir -p $outdir/initrd/bin
mkdir -p $outdir/initrd/lib
mkdir -p $outdir/initrd/etc
mkdir -p $outdir/initrd/tmp
mkdir -p $outdir/initrd/dev
mkdir -p $outdir/initrd/proc
mkdir -p $outdir/initrd/share
mkdir -p $outdir/initrd.mnt
ln -s . $outdir/initrd/usr
ln -s bin $outdir/initrd/sbin
chmod 700 $outdir
cd $outdir

echo_status "Copying program binaries."
for x in bash modprobe lsmod uname gawk lspci find openvpn killall sync dhclient \
         sysctl mount umount sshd ssh-keygen agetty sleep cat ls ps ln strace \
	 swapon swapoff mkdir killall5 reboot sed sort dhclient-script ifconfig \
	 expr hostname route nvi ez-ipupdate pptp rm scp
do
	for y in bin sbin usr/bin usr/sbin; do
		[ -f $build_root/$y/$x ] && cp $build_root/$y/$x initrd/bin/
	done
	[ ! -f initrd/bin/$x ] &&
		echo_error "Did not find program binary for '$x'."
done

for x in iproute2 iptables grub ppp
do
	echo_status "Copy entire $x package."
	while read dummy fn
	do
		mkdir -p $( dirname initrd/$fn )
		cp $build_root/$fn initrd/$fn
	done < $build_root/var/adm/flists/$x
done

echo_status "Copying library files."
for x in $( ls initrd/bin/ )
do
	while read a b c d
	do
		[ "$b" = "=>" ] && [ -n "$d" ] && \
			cp $build_root/${c#/} initrd/lib/
	done < <( chroot $build_root /bin/bash -c \
					"cd /; ldd \`type -p $x\`"; )
done

echo_status "Copying shutdown script."
cp $base/target/$target/shutdown initrd/bin/
chmod +x initrd/bin/shutdown
echo_status "Copying rocknet scripts."
cp -r $build_root/etc/network initrd/etc/
cp -r $build_root/etc/services initrd/etc/
cp $build_root/sbin/if{up,down} initrd/bin/
echo_status "Copying some terminfo database entries."
mkdir -p initrd/share/terminfo/{v,x,l}
cp -r $build_root/usr/share/terminfo/v/vt100 initrd/share/terminfo/v/
cp -r $build_root/usr/share/terminfo/l/linux initrd/share/terminfo/l/
cp -r $build_root/usr/share/terminfo/x/xterm initrd/share/terminfo/x/
echo_status "deleting manpages and other stuff."
rm -rf initrd/share/man
rm -rf initrd/var/adm

echo_status "Copying kernel modules."
cp -a $build_root/lib/modules initrd/lib/
cd initrd/lib/modules/*/
rm -rf pcmcia kernel/fs kernel/drivers/{bluetooth,cdrom,pcmcia,scsi,sound,usb} 
rm -rf kernel/sound
rm -rf kernel/net/{8021q,appletalk,bluetooth,irda,khttpd,decnet,econet,ipx}
rm -rf kernel/drivers/{video,telephony,mtd,message,media,md,input,ide,i2c,ieee1394}
rm -rf kernel/drivers/{hotplug,char,block}
cd $outdir


echo_status "Create init script."
echo -e '#!/bin/bash\ncd; exec /bin/bash --login' > initrd/bin/login-shell
cp $base/target/$target/init.sh initrd/bin/init
chmod +x initrd/bin/login-shell initrd/bin/init
cp $build_root/sbin/{hwscan,dumpnetcfg} initrd/bin/
cp $build_root/usr/share/pci.ids initrd/share/
ln -s bash initrd/bin/sh


SIZE=$(( 1024 * $ROCKCFG_T_ROUTER_INITRD_SIZE ))
REALSIZE=`du -sk initrd | cut -d'	' -f1`

if [ $REALSIZE -gt $SIZE ] ; then
	echo_error "Initrd too small!" 
	echo_status "$REALSIZE kb are needed, but you only want $SIZE kb."
	echo_status "please re-run ./scripts/Config and increase the initrd size!"
	exit 1
fi

echo_status "Creating initrd image ($SIZE kb)."
dd if=/dev/zero of=initrd.img count=$SIZE bs=1024 2>/dev/null
mke2fs -qF initrd.img 2>/dev/null
mount -o loop initrd.img initrd.mnt
cp -a initrd/* initrd.mnt/
umount -d initrd.mnt/
gzip -9 initrd.img
mv initrd.img.gz initrd.img

echo_status "Copy kernel image."
cp $build_root/boot/vmlinuz .

echo_status "Create isolinux setup."
tar --use-compress-program=bzip2 \
	-xOf $base/download/mirror/s/syslinux-3.07.tar.bz2 \
	syslinux-3.07/isolinux.bin > isolinux.bin
sed -e "s,@INITRD_SIZE@,$SIZE," -e "s,@SERIAL_BAUD@,$ROCKCFG_T_ROUTER_SERIAL_BAUD," \
	$base/target/$target/isolinux.cfg > ./isolinux.cfg

echo_status "Create iso description."
cat > ../isofs.txt <<- EOT
	BOOT    -b isolinux.bin -c boot.catalog
	BOOTx   -no-emul-boot -boot-load-size 4 -boot-info-table
	DISK1   build/${ROCKCFG_ID}/ROCK/router /
EOT

if [ "$ROCK_DEBUG_ROUTER_NOCLEANUP" != 1 ]; then
	echo_status "Cleaning up."
	rm -rf initrd.mnt/ initrd
fi

