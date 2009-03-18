
cd $disksdir

echo_header "Cleaning boot directory:"
rm -rfv boot/*-rock boot/System.map boot/kconfig* boot/initrd*.img boot/*.b boot/second

echo_header "Creating yaboot setup:"
#
echo_status "Extracting yaboot boot loader images."
mkdir -p boot etc
tar --use-compress-program=bzip2 \
    -xf $base/build/${ROCKCFG_ID}/ROCK/pkgs/yaboot.tar.bz2 \
    usr/lib/yaboot/yaboot -O > boot/yaboot
tar --use-compress-program=bzip2 \
    -xf $base/build/${ROCKCFG_ID}/ROCK/pkgs/yaboot.tar.bz2 \
    usr/lib/yaboot/yaboot.rs6k -O > boot/yaboot.rs6k
mv boot/yaboot.rs6k install.bin
#
echo_status "Creating yaboot config files."
cp -v $base/target/$target/powerpc/{boot.msg,ofboot.b} \
  boot
(
	echo "device=cdrom:" 
	cat $base/target/$target/powerpc/yaboot.conf
) > etc/yaboot.conf
(
	echo "device=cd:"
	cat $base/target/$target/powerpc/yaboot.conf
) > boot/yaboot.conf
#
echo_status "Moving image (initrd) to boot directory."
mv -v initrd.gz boot/
#
echo_status "Copy more config files."
cp -v $base/target/$target/powerpc/mapping .
#
echo_status "Copying oldworld pmac support files..."
rm -rf oldworld
mkdir -p oldworld
cp -v $base/download/mirror/B/BootX_1.2.2.sit oldworld/
cp -v $base/target/$target/powerpc/oldworld-readme.txt oldworld/README.txt
#
datadir="build/${ROCKCFG_ID}/ROCK/livecd"
cat > ../isofs_arch.txt <<- EOT
	BOOT	-hfs -part -map $datadir/mapping -hfs-volid "ROCK_Linux_CD"
	BOOTx	-hfs-bless boot -sysid PPC -l -L -r -T -chrp-boot
	BOOTx   -prep-boot install.bin
	DISK1	$datadir/boot/ boot/
	DISK1	$datadir/etc/ etc/
	DISK1	$datadir/oldworld/ oldworld/
	DISK1	$datadir/install.bin install.bin
EOT

