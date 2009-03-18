
if any_installed "boot/initrd.img" ; then
	kver=`find /boot/initrd.img -printf '%l\n' | sed 's,.*initrd-,,; s,\.img$,,;'`
	echo "Re-Creating initrd ($kver) ..."
	/sbin/mkinitrd $kver
fi

