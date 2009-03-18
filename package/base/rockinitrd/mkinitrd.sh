#!/bin/bash

kernel=`uname -r`
targetdir=`mktemp -d`
empty=0

rootdir="/"
cross_compile=""
initrdfs="cramfs"
block_size=""
ramdisk_size=8192

# Successfully tested combinations: <arch> <blocksize> <initrdfs>
#	ARM (QEMU)			1024			ext2fs
#	ARM (QEMU)			4096			cramfs
#	x86 (QEMU)			1024			ext2fs
#	x86 (QEMU)			4096			cramfs

for P in find sed grep xargs mkdir cp mknod mount sort uniq tr file rm ln \
    mount umount readelf ; do
	if ! type -p "$P" > /dev/null ; then
		echo "Can't find required program '$P'! Aborting..."
		exit 1
	fi
done
while [ ${#} -gt 0 ] ; do
	case "${1}" in
	empty) empty=1 ;;
	-root) 
		if [ -d "${2}/" ]; then
			rootdir="${2%/}" ; shift
		else
			echo "Can't open ${2}: No such directory."
			echo "Usage: ${0} [ kernel-version ]"
			exit 1
		fi
		;;
	-cross) cross_compile="${2}" ; shift ;;
	-bs) block_size="${2}" ; shift ;;
	-fs)
		case "${2}" in
		ext2fs|ext3fs|cramfs|ramfs) initrdfs="${2}" ; shift ;;
		*)
			echo "Filesystem ${2} not supported as initrd filesystem."
			exit 1
			;;
		esac
		;;
	*)
		if [ -d "${rootdir}/lib/modules/${1}" ]; then
			kernel="${1}"
			echo "kernel ${kernel}"
		else
			echo "Can't open ${rootdir}/lib/modules/${1}: No such directory."
			echo "Usage: ${0} [ kernel-version ]"
			exit 1
		fi
		;;
	esac
	shift
done

case ${initrdfs} in
	ext2fs|ext3fs|cramfs) 
		initrd_img="${rootdir}/boot/initrd-${kernel}.img"
		;;
	ramfs)
		initrd_img="${rootdir}/boot/initrd-${kernel}.cpio"
		;;
esac

get_module_dependencies() {
        module="${1}"
        deps=`/sbin/modinfo -F depends ${module} 2>/dev/null | tr ',' ' '`
        if [ -n "${deps}" ] ; then
                for dep in ${deps} ; do
                        echo "`get_module_dependencies ${dep}`"
                done
        fi
        echo "${module}";
}

add_module_to_initrd() {
	# adds a module and all it's dependencies to the initrd
	module_name="${1}"
	parameter="${2}"
	module_name=${module_name/.ko/} # just in case, shouldn't be

	for dependant_module in `get_module_dependencies ${module_name} | sort | uniq` ; do
		module="`find ${rootdir}/lib/modules/${kernel} -name "${dependant_module}.o" -o -name "${dependant_module}.ko"`"
		[ -f "${targetdir}/${module}" ] && return # skip dupes
		echo "Adding ${module}."
		mkdir -p ${targetdir}/${module%/*}
		cp ${module} ${targetdir}/${module}
	done

	echo "/sbin/modprobe ${module_name} ${parameter}" >> ${targetdir}/etc/conf/kernel
}

echo "Creating ${initrd_img} ..."
mkdir -p ${targetdir}/etc/conf
mkdir -p ${targetdir}/lib/modules/${kernel}
if [ "${empty}" = 0 ] ; then
	grep '^modprobe ' ${rootdir}/etc/conf/kernel | grep -v 'no-initrd' | \
		sed 's,[ 	]#.*,,' | \
		while read a b c; do
			module="$( find ${rootdir}/lib/modules/${kernel}/ -name "${b}.o" -o -name "${b}.ko" )"
			if [ -z "${module}" ] ; then
				echo "$0: ${b} is no longer a module in ${kernel}" >&2
				echo "$0: Please either adjust /etc/conf/kernel or the configuration for the kernel V${kernel}" >&2
				continue
			fi
			add_module_to_initrd "${b}" "${c}"
		done
fi
depmod -b ${targetdir} ${kernel}

mkdir -p ${targetdir}/{dev,root,tmp,proc,sys}
mknod ${targetdir}/dev/ram0	b 1 0
mknod ${targetdir}/dev/null	c 1 3
mknod ${targetdir}/dev/zero	c 1 5
mknod ${targetdir}/dev/tty	c 5 0
mknod ${targetdir}/dev/console	c 5 1

# this copies a set of programs and the necessary libraries into a
# chroot environment

echo -n "Checking necessary fsck programs ... "
while read dev a mnt b fs c ; do
	[ -e "${rootdir}/sbin/fsck.${fs}" ] && echo "/sbin/fsck.${fs} /sbin/fsck.${fs}"
done < <( mount ) | sort | uniq >/etc/conf/initrd/initrd_fsck
echo "/sbin/fsck /sbin/fsck" >>/etc/conf/initrd/initrd_fsck
echo "done"

libdirs=""
for N in ${rootdir}/lib `sed -e"\,^/, ! d; s,^\(.*\),${rootdir}\1," ${rootdir}/etc/ld.so.conf | tr '\n' ' '` ; do
	[ -d "$N" ] && libdirs="$libdirs $N"
done

needed_libs() {
	local x="${1}" library

	${cross_compile}readelf -d ${x} 2>/dev/null | grep "(NEEDED)" |
		sed -e"s,.*Shared library: \[\(.*\)\],\1," |
		while read library ; do
			find ${libdirs} -maxdepth 1 -name "${library}" 2>/dev/null |
			sed -e "s,^${rootdir},,g" | tr '\n' ' '
		done
}

echo -n "Copying other files ... "
for x in ${rootdir}/etc/conf/initrd/initrd_* ; do
	[ -f ${x} ] || continue
	while read file target cpopt; do
		if [ -z "$file" -o "$file" = "#" ]; then
			continue
		fi
		file="${rootdir}/${file}"
		if [ ! -e ${file} ] ; then
			echo "${file} is requested by ${x} but doesn't exist!" >&2
			continue
		fi

		while read f ; do
			tfile=${targetdir}/${target}${f#${file}}
			[ -e ${tfile} ] && continue

			if [ -d ${f} -a ! -L ${f} ] ; then
				mkdir -p ${tfile}
				continue
			else
				mkdir -p ${tfile%/*}
			fi

			cp ${cpopt:--a} ${f} ${tfile}

			file -L ${f} | grep -q ELF || continue
			libs="${libs} `needed_libs ${f}`"
		done < <( find "${file}" )
	done < <( grep '^[^#]' ${x} )
done
echo "done"

echo -n "Copying required libraries ... "
while [ -n "${libs}" ] ; do
	oldlibs=${libs}
	libs=""
	for x in ${oldlibs} ; do
		[ -e ${targetdir}/${x} ] && continue
		mkdir -p ${targetdir}/${x%/*}
		cp ${rootdir}/${x} ${targetdir}/${x}
		file -L ${rootdir}/${x} | grep -q ELF || continue
		for y in `needed_libs ${rootdir}/${x}` ; do
			[ ! -e "${targetdir}/${y}" ] && libs="${libs} ${y}"
		done
	done
done
echo "done"

echo "Creating links for identical files ..."
while read ck fn
do
	# don't link empty files...
	if [ "${oldck}" = "${ck}" -a -s "${fn}" ] ; then
		echo "\`- Found ${fn#${targetdir}} -> ${oldfn#${targetdir}}."
		rm ${fn} ; ln -s /${oldfn#${targetdir}} ${fn}
	else
		oldck=${ck} ; oldfn=${fn}
	fi
done < <( find ${targetdir} -type f | xargs md5sum | sort )

# though this is not clean, it helps avoid a warning from fsck about
# it being unable to determine wether a filesystem is mounted.
ln -s /proc/mounts ${targetdir}/etc/mtab

echo "Creating initrd filesystem image (${initrdfs}): "
case "${initrdfs}" in
cramfs)
	[ "${block_size}" == "" ] && block_size=4096
	/sbin/mkfs.cramfs -b ${block_size} ${targetdir} ${initrd_img}
	;;
ramfs)
#	cp -a ${targetdir}/{linuxrc,init}
	( cd ${targetdir} ; find | cpio -o -c > ${initrd_img} ; )
	;;	
ext2fs|ext3fs)
	[ "${block_size}" == "" ] && block_size=1024
	block_count=$(( ( 1024 * ${ramdisk_size} ) / ${block_size} ))

	echo "Creating temporary files."
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
			echo "No free loopback device found!"
			rm -f ${tmpfile} ; rmdir ${tmpdir}; exit 1
		fi
	fi
	echo "Using loopback device ${tmpdev}."
	losetup "${tmpdev}" ${initrd_img}

	echo "Writing initrd image file."
	/sbin/mkfs.${initrdfs:0:4} -b ${block_size} -m 0 -N 360 -q ${tmpdev} &> /dev/null
	mount -t ${initrdfs:0:4} ${tmpdev} ${tmpdir}
	rmdir ${tmpdir}/lost+found/
	cp -a ${targetdir}/* ${tmpdir}
	umount ${tmpdir}
 
	echo "Removing temporary files."
	losetup -d ${tmpdev}
	rm -rf ${tmpdir}
	;;
esac

echo "Compressing initrd image file."
gzip -9 -c ${initrd_img} > ${initrd_img}.gz

rm -rf ${targetdir}
echo "Done."
