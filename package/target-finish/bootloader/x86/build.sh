
if pkginstalled syslinux ; then
	use_isolinux=1
else
	use_isolinux=0
fi
use_mdlbl=1

cd $disksdir

echo "Creating lilo config:"
cp $confdir/x86/lilo-* boot/

echo "Creating floppy disk images:"
cp $confdir/x86/makeimages.sh .
chmod +x makeimages.sh

# if [ $use_mdlbl -eq 1 ]
# then
# 	tar $taropt $base/download/mirror/m/mdlbl-$mdlbl_ver.tar.bz2
# 	cd mdlbl-$mdlbl_ver
# 	cp ../boot/vmlinuz .; cp ../initrd.gz initrd; ./makedisks.sh
# 	for x in disk*.img; do mv $x ../floppy${x#disk}; done; cd ..
# 	du -sh floppy*.img | while read x; do echo $x; done
# else
# 	tmpfile=`mktemp -p $PWD`
# 	if sh ./makeimages.sh &> $tmpfile; then
# 		cat $tmpfile | while read x; do echo "$x"; done
# 	else
# 		cat $tmpfile | while read x; do echo "$x"; done
# 	fi
# 	rm -f $tmpfile
# 	cat > $xroot/ROCK/isofs_arch.txt <<- EOT
# 		BOOT	-b ${ROCKCFG_SHORTID}/boot_288.img -c ${ROCKCFG_SHORTID}/boot.catalog
# 	EOT
# fi

if [ $use_isolinux -eq 1 ]
then
	syslinux_ver="$( grep " syslinux " $base/config/$config/packages | cut -f6 -d" " )"

	echo "Creating isolinux setup:"
	#
	echo "Extracting isolinux boot loader."
	rm -rf isolinux ; mkdir -p isolinux
	cp -a $root/usr/share/syslinux/isolinux.bin isolinux/isolinux.bin
	#
	echo "Creating isolinux config file."
	cp $confdir/x86/{isolinux.cfg,help?.txt} isolinux/
	#
	echo "Copy images to isolinux directory."
	[ -e $root/boot/memtest86.bin ] && \
		cp $root/boot/memtest86.bin isolinux/memtest86 || true
	cp $ROCKCFG_PKG_1ST_STAGE_INITRD.gz $root/boot/vmlinuz* isolinux/
	#
	cat > $root/ROCK/isofs_arch.txt <<- EOT
		BOOT	-b boot/isolinux/isolinux.bin -c boot/isolinux/boot.catalog
		BOOTx	-no-emul-boot -boot-load-size 4 -boot-info-table
		DISK1	$datadir/isolinux/ boot/isolinux/
	EOT
fi
