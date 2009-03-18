
use_yaboot=1

cd $disksdir

# yaboot doesn't seem to like the symlink.
echo "Renaming kernel image:"
rm -vf boot/vmlinux
mv -vf boot/vmlinux_* boot/vmlinux

if [ $use_yaboot -eq 1 ]
then
	echo "Creating yaboot setup:"
	#
	echo "Extracting yaboot boot loader images."
	mkdir -p boot etc
	cp -v $root/usr/lib/yaboot/yaboot boot/
	cp -v $root/usr/lib/yaboot/yaboot.rs6k boot/
	cp -v boot/yaboot.rs6k install.bin
	#
	echo "Creating yaboot config files."
	cp -v $confdir/powerpc/{boot.msg,ofboot.b} \
	  boot
	(
		echo "device=cdrom:" 
		cat $confdir/powerpc/yaboot.conf
	) > etc/yaboot.conf
	(
		echo "device=cd:"
		cat $confdir/powerpc/yaboot.conf
	) > boot/yaboot.conf
	#
	echo "Copy more config files."
	cp -v $confdir/powerpc/mapping .
	#
	cat > $root/ROCK/isofs_arch.txt <<- EOT
		BOOT	-hfs -part -map $datadir/mapping -hfs-volid "ROCK_Linux_CD"
		BOOTx	-hfs-bless boot -sysid PPC -l -L -r -T -chrp-boot
		BOOTx   --prep-boot install.bin
		DISK1	$datadir/etc/ etc/
		DISK1	$datadir/install.bin install.bin
	EOT
#		SCRIPT  sh $confdir/powerpc/bless-rs6k.sh $disksdir
fi

