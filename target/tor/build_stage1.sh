
echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,proc,sys,mnt/{cdrom,floppy,stick,}}
mkdir -p $disksdir/initrd/mnt/{cowfs_ro/{etc,home,bin,sbin,opt,usr/{bin,sbin},tmp,var,lib},cowfs_rw}
cd $disksdir/initrd

#
echo_status "Creating read-only symlinks..."
for d in etc home bin sbin opt usr tmp var lib ; do
	ln -s mnt/cowfs_rw/$d $d
	ln -s ../cowfs_ro/$d mnt/cowfs_rw/$d
done
#
if [ -L $disksdir/2nd_stage/lib64 ] ; then
	ln -s mnt/cowfs_rw/lib64 lib64
	ln -s ../cowfs_ro/lib64 mnt/cowfs_rw/lib64
fi

rock_targetdir="$base/target/$target/"
rock_target="$target"

rootdir="$base/build/$ROCKCFG_ID"
targetdir="$disksdir/initrd"
cross_compile=""
if [ "$ROCKCFG_CROSSBUILD" = "1" ] ; then
	cross_compile="`find ${base}/ROCK/tools.cross/ -name "*-readelf"`"
	cross_compile="${cross_compile##*/}"
	cross_compile="${cross_compile%%readelf}"
fi
initrdfs="ext2fs"
block_size=""
ramdisk_size=12288

case ${initrdfs} in
	ext2fs|ext3fs|cramfs) 
		initrd_img="${disksdir}/initrd.img"
		;;
	ramfs)
		initrd_img="${disksdir}/initrd.cpio"
		;;
esac

echo_status "Creating some device nodes"
mknod ${targetdir}/dev/ram0	b 1 0
mknod ${targetdir}/dev/null	c 1 3
mknod ${targetdir}/dev/zero	c 1 5
mknod ${targetdir}/dev/tty	c 5 0
mknod ${targetdir}/dev/console	c 5 1

# this copies a set of programs and the necessary libraries into a
# chroot environment

echo_status "Create checkisomd5 binary"
cp -r ${base}/misc/isomd5sum ${base}/build/${ROCKCFG_ID}/
cat >${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh <<EOF
#!/bin/bash
cd /isomd5sum
make clean
make CC=gcc
EOF
chmod +x ${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh
chroot ${base}/build/${ROCKCFG_ID}/ /compile_isomd5sum.sh
cp ${base}/build/${ROCKCFG_ID}/isomd5sum/checkisomd5 mnt/cowfs_ro/bin/
rm -rf ${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh ${base}/build/${ROCKCFG_ID}/isomd5sum

echo_status "Copying and adjusting linuxrc script"
cp ${base}/target/${target}/linuxrc.sh linuxrc
chmod +x linuxrc
sed -i -e "s,\(^STAGE_2_BIG_IMAGE=\"\)\(2nd_stage.img.z\"$\),\1${ROCKCFG_SHORTID}/\2," \
       linuxrc

libdirs="${rootdir}/lib `sed -e"s,^\(.*\),${rootdir}\1," ${rootdir}/etc/ld.so.conf | tr '\n' ' '`"

needed_libs() {
	local x="${1}" library

	${cross_compile}readelf -d ${x} 2>/dev/null | grep "(NEEDED)" |
		sed -e"s,.*Shared library: \[\(.*\)\],\1," |
		while read library ; do
			find ${libdirs} -name "${library}" 2>/dev/null |
			sed -e "s,^${rootdir},,g" | tr '\n' ' '
		done
}

libs="${libs} `needed_libs bin/checkisomd5`"

echo_status "Copying other files ... "
for x in ${rock_targetdir}/initrd/initrd_* ; do
	[ -f ${x} ] || continue
	while read file target ; do
		file="${rootdir}/${file}"
		[ -e ${file} ] || continue

		while read f ; do
			tfile=${targetdir}/${target}${f#${file}}
			[ -e ${tfile} ] && continue

			if [ -d ${f} -a ! -L ${f} ] ; then
				mkdir -p "${tfile}"
				continue
			else
				mkdir -p "${tfile%/*}"
			fi

			cp -a ${f} ${tfile}

			file -L ${f} | grep -q ELF || continue
			libs="${libs} `needed_libs ${f}`"
		done < <( find "${file}" )
	done < ${x}
done

for x in modprobe.static modprobe.static.old \
         insmod.static insmod.static.old
do
	if [ -f ../2nd_stage/sbin/${x/.static/} ]; then
		rm -f mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/${x/.static/} mnt/cowfs_ro/sbin/
	fi
	if [ -f ../2nd_stage/sbin/$x ]; then
		rm -f mnt/cowfs_ro/bin/$x mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/$x mnt/cowfs_ro/sbin/
		ln -sf $x mnt/cowfs_ro/bin/${x/.static/}
	fi
done
#
echo_status "Copy kernel modules."
for x in ../2nd_stage/lib/modules/*/kernel/drivers/{scsi,cdrom,ide,ide/pci,ide/legacy}/*.{ko,o} ; do
	# this test is needed in case there are only .o or only .ko files
	if [ -f $x ]; then
		xx=mnt/cowfs_ro/${x#../2nd_stage/}
		mkdir -p $( dirname $xx ) ; cp $x $xx
		strip --strip-debug $xx 
	fi
done
#
for x in ../2nd_stage/lib/modules/*/modules.{dep,pcimap,isapnpmap} ; do
	cp $x mnt/cowfs_ro/${x#../2nd_stage/} || echo "not found: $x" ;
done
#
rm -f mnt/cowfs_ro/lib/modules/[0-9]*/kernel/drivers/net/{dummy,ppp*}.{o,ko}

echo_status "Copying required libraries ... "
while [ -n "${libs}" ] ; do
	oldlibs=${libs}
	libs=""
	for x in ${oldlibs} ; do
		[ -e "${targetdir}/${x}" ] && continue
		mkdir -p "${targetdir}/${x%/*}"
		cp ${rootdir}/${x} ${targetdir}/${x}
		file -L ${rootdir}/${x} | grep -q ELF || continue
		for y in `needed_libs ${rootdir}/${x}` ; do
			[ ! -e "${targetdir}/${y}" ] && libs="${libs} ${y}"
		done
	done
done

echo_status "Creating links for identical files ..."
while read ck fn
do
	# don't link empty files...
	if [ "${oldck}" = "${ck}" -a -s "${fn}" ] ; then
		echo_status "\`- Found ${fn#${targetdir}} -> ${oldfn#${targetdir}}."
		rm ${fn} ; ln -s /${oldfn#${targetdir}} ${fn}
	else
		oldck=${ck} ; oldfn=${fn}
	fi
done < <( find ${targetdir} -type f | xargs md5sum | sort )

if [ "${ROCKCFG_TARGET_TOR_SIZE}" == "files" ] ; then
	echo_status "Compressing binaries"
	files="`find . -type f -print0 | xargs -0 file | grep ELF | cut -f1 -d:`"
	$base/build/$ROCKCFG_ID/usr/bin/upx2 --brute $files < /proc/$$/fd/0 > /proc/$$/fd/1 2> /proc/$$/fd/2 || true
fi

cd ..

echo_header "Creating initrd filesystem image: "

ramdisk_size=8139

[ "${block_size}" == "" ] && block_size=1024
block_count=$(( ( 1024 * ${ramdisk_size} ) / ${block_size} ))

echo_status "Creating temporary files."
tmpdir=`mktemp -d` ; mkdir -p ${tmpdir}
dd if=/dev/zero of=${initrd_img} bs=${block_size} count=${block_count} &> /dev/null
tmpdev="`losetup -f 2>/dev/null`"
if [ -z "${tmpdev}" ] ; then
	for x in /dev/loop* /dev/loop/* ; do
		[ -b "${x}" ] || continue
		losetup ${x} 2>&1 >/dev/null || tmpdev="${x}"
		[ -n "${tmpdev}" ] && break
	done
	if [ -z "${tmpdev}" ] ; then
		echo_status "No free loopback device found!"
		rm -f ${tmpfile} ; rmdir ${tmpdir}; exit 1
	fi
fi
echo_status "Using loopback device ${tmpdev}."
losetup "${tmpdev}" ${initrd_img}

echo_status "Writing initrd image file."
mkfs.${initrdfs:0:4} -b ${block_size} -m 0 -N 360 -q ${tmpdev} &> /dev/null
mount -t ${initrdfs:0:4} ${tmpdev} ${tmpdir}
rmdir ${tmpdir}/lost+found/
cp -a ${targetdir}/* ${tmpdir}
umount ${tmpdir}

echo_status "Removing temporary files."
losetup -d ${tmpdev}
rm -rf ${tmpdir}
#
echo_status "Compressing initrd image file."
gzip -9 -c ${initrd_img} > ${initrd_img}.gz
mv ${initrd_img%.img}{.img,}.gz

target="$rock_target"
