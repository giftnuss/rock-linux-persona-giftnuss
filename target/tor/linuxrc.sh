#!/bin/bash

STAGE_2_BIG_IMAGE="2nd_stage.img.z"

#640kB, err, 64 MB should be enought for the tmpfs ;-)
TMPFS_OPTIONS="size=67108864"

mod_load_info () { # {{{
	read os host version rest < <( uname -a )
	if [ -z "${os}" ] ; then
		echo "Can't run \`uname -a\`"
		return
	elif [ "${os}" != "Linux" ] ; then
		echo "Your operating system is not supported ?!"
		return
	fi

	mod_loader="/sbin/insmod"
	mod_dir="/lib/modules/"

	# kernel module suffix for <= 2.4 is .o, .ko if above
	if [ ${version:2:1} -gt 4 ] ; then
		mod_suffix=".ko"
		mod_suffix_len=3
	else
		mod_suffix=".o"
		mod_suffix_len=2
	fi
} # }}}
doboot() { # {{{
	echo "doboot starting - trying to exec /sbin/init"
	exec /sbin/init
} # }}}
trymount() { # {{{
	source=${1}
	target=${2}
	mount -t iso9600 -o ro ${source} ${target} && return 0
	mount -t ext3 -o ro ${source} ${target} && return 0
	mount -t ext2 -o ro ${source} ${target} && return 0
	mount -t minix -o ro ${source} ${target} && return 0
	mount -t vfat -o ro ${source} ${target} && return 0
	return -1
} # }}}
httpload() { # {{{
	echo -n "Enter base URL (e.g. http://1.2.3.4/rock): "

	read baseurl
	[ -z "${baseurl}" ] && return

	cat <<EOF
Select a stage 2 image file:

     0. ${STAGE_2_BIG_IMAGE}
     1. ${STAGE_2_SMALL_IMAGE}

EOF
	echo -n "Enter number or image file name (default=0): "
	read filename

	if [ -z "${filename}" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${filename}" == "0" ] ; then
		filename=${STAGE_2_BIG_IMAGE}
	elif [ "${filename}" == "1" ] ; then
		filename="${STAGE_2_SMALL_IMAGE}"
	fi

	url="${baseurl%/}/${filename}"
	echo "[ ${url} ]"
	export ROCK_INSTALL_SOURCE_URL=${baseurl}

	exit_linuxrc=1;
	if ! mkdir /mnt_root ; then
		echo "Can't create /mnt_root"
		exit_linuxrc=0
	fi

	if ! mount -t tmpfs -O ${TMPFS_OPTIONS} none /mnt_root ; then
		echo "Can't mount /mnt_root"
		exit_linuxrc=0
	fi

	wget -O - ${url} | tar ${STAGE_2_COMPRESS_ARG} -C /mnt_root -xf -

	echo "finished ... now booting 2nd stage"
	doboot
} # }}}
load_modules() { # {{{
# this starts the module loading shell
	directory=${1}
	cat <<EOF
module loading shell

you can navigate through the filestem with 'cd'. for loading a module
simply enter the shown name, to exit press enter on a blank line.

EOF
	cd ${directory}
	while : ; do
		echo "Directories:"
		count=0
		while read inode ; do
			[ -d "${inode}" ] || continue
			echo -n "	[	${inode}	]"
			count=$((${count}+1))
			if [ ${count} -gt 3 ] ; then
				echo
				count=0
			fi
		done < <( ls ) | expand -t1,3,19,21,23,39,41,43,59,61,63,78
		echo
		echo "Modules:"
		count=0
		while read inode ; do
			[ -f "${inode}" ] || continue
			[ "${inode%${mod_suffix}}" == "${inode}" ] && continue
			echo -n "	[	${inode%${mod_suffix}}	]"
			count=$((${count}+1))
			if [ ${count} -gt 3 ] ; then
				echo
				count=0
			fi
		done < <( ls ) | expand -t1,3,19,21,23,39,41,43,59,61,63,78
		echo
		echo -n "[${PWD##*/} ] > "
		read cmd par 
		if [ "${cmd}" == "cd" ] ; then
			cd ${par}
		elif [ -f "${cmd}${mod_suffix}" ] ; then
			insmod ${PWD%/}/${cmd}${mod_suffix} ${par}
		elif [ -z "${cmd}" ] ; then
			break
		else
			echo "No such module: ${cmd}"
		fi
	done
	return
} # }}}
getdevice () { # {{{
	while : ; do
		echo -en "\nDevice file to use (q to return) : ";
		read device;
		[ "${device}" == "q" ] && return -1;
		if [ ! -e "${device}" ] ; then
			echo -e "\nNot a valid device!"
		else 
			devicefile=${device}
			return 0;
		fi
	done
} # }}}
getcdromdevice () { # {{{
	cdroms="${1}"
	floppies="${2}"
	autoboot="${3}"
	devicelists="/dev/cdroms/* /dev/floppy/*"

	[ "${cdroms}" == "0" -a "${floppies}" == "0" ] && return -1

	devnr=0
	for dev in ${devicelists} ; do
		[ -e "${dev}" ] || continue
		[[ ${dev} = /dev/cdroms* ]] && [ "${cdroms}" == "0" ] && continue
		[[ ${dev} = /dev/floppy* ]] && [ "${floppies}" == "0" ] && continue

		eval "device_${devnr}='${dev}'"
		devnr=$((${devnr}+1))
	done

	[ ${devnr} -eq 0 ] && return -1
	
	x=0
	floppy=1
	cdrom=1
	while [ ${x} -lt ${devnr} ] ; do
		eval "device=\${device_${x}}"
		if [[ ${device} = /dev/cdrom* ]]  ; then
			echo "	${x}. CD-ROM #${cdrom} (IDE/ATAPI or SCSI)"
			cdrom=$((${cdrom}+1))
		fi
		if [[ ${device} = /dev/flopp* ]] ; then
			echo "	${x}. FDD (Floppy Disk Drive) #${floppy}"
			floppy=$((${floppy}+1))
		fi
		x=$((${x}+1))
	done

	echo -en "\nEnter number or device file name (default=0): "

	if [ ${autoboot} -eq 1 ] ; then
		echo "0"
		text=0
	else
		read text
	fi

	[ -z "${text}" ] && text=0

	while : ; do
		if [ -e "${text}" ] ; then
			devicefile="${text}"
			return 0
		fi

		eval "text=\"\${device_${text}}\""
		if [ -n "${text}" ] ; then
			devicefile="${text}"
			return 0
		fi

		echo -n "No such device found. Try again (enter=back): "
		read text
		[ -z "${text}" ] && return -1
	done
	
	return 1;
} # }}}
prepare_root () { # {{{
	local ret=0 F

	echo "preparing /dev"
	cd /dev || ret=1
	rm -rf fd
	ln -svf /proc/kcore core || ret=1
	ln -svf /proc/self/fd fd || ret=1
	ln -svf fd/0 stdin || ret=1
	ln -svf fd/1 stdout || ret=1
	ln -svf fd/2 stderr || ret=1
	cd / || ret=1

	ln -svf /mnt/cowfs_ro/* /mnt/cowfs_rw-new/
	rm -rf /mnt/cowfs_rw-new/{home,tmp}
	mkdir -p /mnt/cowfs_rw-new/{home,tmp}
	chmod 1777 /mnt/cowfs_rw-new/tmp
	mkdir -p /mnt/cowfs_rw-new/home/{rocker,root}
	chmod 755 /mnt/cowfs_rw-new/home/rocker
	chmod 700 /mnt/cowfs_rw-new/home/root
	if ! chown 1000:100 /mnt/cowfs_rw-new/home/rocker ; then
		echo "could not chown /mnt/cowfs_rw-new/home/rocker to rocker:users"
		ret=1
	fi

	mount --move /mnt/cowfs_rw-new /mnt/cowfs_rw
	rm -rf /mnt/cowfs-rw-new

	return $ret
} # }}}
load_ramdisk_file() { # {{{
	local devicetype=${1} autoboot=${2}

	echo -en "Select a device for loading the 2nd stage system from: \n\n"

	if [ "${devicetype}" == "cdroms" ] ; then
		getcdromdevice 1 1 ${autoboot} || return
	else 
		getdevice || return
	fi
	
	cat << EOF
Select a stage 2 image file:

	1. ${STAGE_2_BIG_IMAGE}

EOF
	echo -n "Enter number or image file name (default=1): "
	if [ ${autoboot} -eq 1 ] ; then
		text=1
	else
		read text
	fi

	if [ -z "${text}" -o "${text}" = "1" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	else
		filename="${text}"
	fi

	exit_linuxrc=1
	echo "Using ${devicefile}:${filename}."

	if ! mkdir -p /mnt/cdrom ; then
		echo "Can't create /mnt/cdrom"
		exit_linuxrc=0
	fi

	if ! mount ${devicefile} "/mnt/cdrom" -o ro ; then
		echo "Can't mount /mnt/cdrom"
		exit_linuxrc=0
	fi

	loopdev="dev/loop/0" ; [ ! -e "${loopdev}" ] && loopdev="/dev/loop0"
	if ! losetup "${loopdev}" "/mnt/cdrom/${filename}" ; then
		echo "Can't losetup /mnt/cdrom/${filename}"
		exit_linuxrc=0
	fi

#	mkdir -p /mnt/cowfs_r{o,w}

	if ! mount -t squashfs "${loopdev}" /mnt/cowfs_ro -o ro ; then
		echo "Can't mount squashfs on /mnt/cowfs_ro"
		exit_linuxrc=0
	fi

	if ! mkdir -p /mnt/cowfs_rw-new ; then
		echo "Can't mkdir -p /mnt/cowfs_rw-new"
		exit_linuxrc=0
	fi

	if ! mount -t tmpfs -o ${TMPFS_OPTIONS} tmpfs /mnt/cowfs_rw-new ; then
		echo "Can't mount tmpfs on /mnt/cowfs_rw-new"
		exit_linuxrc=0
	fi

	export ROCK_INSTALL_SOURCE_DEV=${devicefile}
	export ROCK_INSTALL_SOURCE_FILE=${filename}

	if prepare_root ; then 
		rm -rf /mnt/cowfs_rw-new
		doboot
	fi
} # }}}

activate_swap() { # {{{
	echo
	echo -n "Enter file name of swap device: "

	read text
	if [ -n "${text}" ] ; then
		swapon ${text}
	fi
} # }}}
config_net() { # {{{
	ip addr
	echo
	ip route
	echo

	echo -n "Enter interface name (eth0): "
	read dv
	[ -z "${dv}" ] && dv="eth0"

	echo -n "Enter ip (192.168.0.254/24): "
	read ip
	[ -z "${ip}" ] && ip="192.168.0.254/24"

	ip addr add ${ip} dev ${dv}
	ip link set ${dv} up

	echo -n "Enter default gateway (none): "
	read gw
	[ -n "${gw}" ] && ip route add default via ${gw}

	ip addr
	echo
	ip route
	echo
} # }}}
exec_sh() { # {{{
	echo "Quit the shell to return to the stage 1 loader!"
	/bin/sh
} # }}}
checkisomd5() { # {{{
	echo "Select a device for checking: "
	
	getcdromdevice 1 0 0 || return
	echo "Running check..."

	/bin/checkisomd5 ${devicefile}

	echo "done"
	echo "Press Return key to continue."
	read
} # }}}

emit_udev_events() { # {{{
	/sbin/udevtrigger
	/sbin/udevsettle
} # }}}

input=1
exit_linuxrc=0
[ -z "${autoboot}" ] && autoboot=0

mount -t tmpfs -o ${TMPFS_OPTIONS} tmpfs /tmp || echo "Can't mount /tmpfs"
mount -t proc proc /proc || echo "Can't mount /proc"
mount -t sysfs sysfs /sys || echo "Can't mount sysfs on /sys"
mount -t tmpfs tmpfs /dev || echo "Can't mount a tmpfs on /dev"

export PATH="/sbin:/bin:/usr/sbin:/usr/bin:$PATH"

cp -r /lib/udev/devices/* /dev

mount -t devpts devpts /dev/pts || echo "Can't mount devpts on /dev/pts"

echo "" > /proc/sys/kernel/hotplug
/sbin/udevd --daemon

# create nodes for devices already in kernel
emit_udev_events

mod_load_info

# some devices (scsi...) need time to settle...
echo "Waiting for devices to settle..."
sleep 5

ip addr add 127.0.0.1 dev lo
ip link set lo up

if [ ${autoboot} -eq 1 ] ; then
	load_ramdisk_file cdroms 1
fi
autoboot=0
cat << EOF
     ============================================
     ===   ROCK Linux 1st stage boot system   ===
     ============================================

The ROCK Linux install / rescue system boots up in two stages. You
are now in the first of this two stages and if everything goes right
you will not spend much time here. Just load your SCSI and networking
drivers (if needed) and configure the installation source so the
2nd stage boot system can be loaded and you can start the installation.
EOF
while [ ${exit_linuxrc} -eq 0 ] ; do
	cat <<EOF
	0. Load 2nd stage system from cdrom or floppy drive
	1. Load 2nd stage system from any device
	2. Load 2nd stage system from network
	3. Configure network interfaces (IPv4 only)
	4. Load kernel modules from this disk
	5. Load kernel modules from another disk
	6. Activate already formatted swap device
	7. Execute a shell (for experts!)
	8. Validate a CD/DVD against its embedded checksum

EOF
	echo -n "What do you want to do [0-8] (default=0)? "
	read text
	[ -z "${text}" ] && text=0
	input=${text//[^0-9]/}

	
	case "${input}" in
		0)
		  load_ramdisk_file cdroms 0
		  ;;
		1)
		  load_ramdisk_file any 0
		  ;;
		2)
		  httpload
		  ;;
		3)
		  config_net
		  ;;
		4)
		  load_modules "${mod_dir}"
		  ;;
		5)
		  mkdir "/mnt_floppy" || echo "Can't create /mnt_floppy"
		  trymount "/dev/floppy/0" "/mnt_floppy" && load_modules "/mnt_floppy"
		  umount "/mnt_floppy" || echo "Can't umount /mnt_floppy"
		  rmdir "/mnt_floppy" || echo "Can't remove /mnt_floppy"
		  ;;
		6)
		  activate_swap
		  ;;
		7)
		  exec_sh
		  ;;
		8)
		  checkisomd5
		  ;;
		*)
		  echo "No such option present!"
	esac
done

exec /linuxrc
echo "Can't start /linuxrc!! Life sucks.\n\n"
