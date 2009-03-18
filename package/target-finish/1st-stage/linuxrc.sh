#!/bin/bash

export PATH="/bin:/usr/bin:/sbin:/usr/sbin"

STAGE_2_BIG_IMAGE="2nd_stage.tar.gz"
STAGE_2_SMALL_IMAGE="2nd_stage_small.tar.gz"
# Use -m to not let tar complain about modification times in the future, e.g.
# if the system clock is not set.
STAGE_2_COMPRESS_ARG="--use-compress-program=gzip -m"

#640kB, err, 64 MB should be enought for the tmpfs ;-)
# 80 MB is better...
TMPFS_OPTIONS="size=83886060"

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
	if ! mkdir -p /mnt_root/old_root ; then
		echo "Can't create /mnt_root/old_root"
		return 1
	fi

	if [ ! -f /mnt_root/sbin/init ] ; then
		echo "Can't find /mnt_root/sbin/init!"
		return 1
	fi

	# pivot_root may or may not change the PWD and root of the
	# caller, so we change into the new root directory first.
	cd /mnt_root
	if ! pivot_root . "/mnt_root/old_root" ; then
		echo "Can't call pivot_root"
		cd /
		return 1
	fi

	if ! mount --move /old_root/dev /dev ; then
		echo "Can't remount /old_root/dev as /dev"
	fi

	if ! mount --move /old_root/proc /proc ; then
		echo "Can't remount /old_root/proc as /proc"
	fi

	if [[ "$( < /proc/version )" == "Linux version 2.6."* ]] ; then
		if ! mount --move /old_root/sys /sys ; then
			echo "Can't remount /old_root/sys as /sys"
		fi
	fi

	if ! umount /old_root/tmp ; then
		echo "Can't umount /old_root/tmp"
	fi

	sed -e "s, /mnt_root , / ," /old_root/etc/mtab > /etc/mtab

	# Kill udevd so /old_root can be unmounted.
	udev_pid="$( ps -C udevd -o pid= )"
	[ "$udev_pid" ] && kill $udev_pid

	exec chroot . sh -c "exec /sbin/init" <dev/console >dev/console 2>&1

	echo "Can't exec /sbin/init!"
	return 1
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

	if ! mkdir -p /mnt_root ; then
		echo "Can't create /mnt_root"
		return 1
	fi

	if ! mount -t tmpfs -O ${TMPFS_OPTIONS} tmpfs /mnt_root ; then
		echo "Can't mount /mnt_root"
		return 1
	fi

	if ! wget -O - ${url} | tar ${STAGE_2_COMPRESS_ARG} -C /mnt_root -xf - ; then
		echo "Downloading and extracting image to /mnt_root failed"
	else
		echo "finished ... now booting 2nd stage"
	
		if ! doboot ; then
			echo "Booting 2nd stage failed"
		fi
	fi
	umount /mnt_root
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
load_ramdisk_file() { # {{{
	devicetype=${1}
	autoboot=${2}
	mountopts=""

	echo -en "Select a device for loading the 2nd stage system from: \n\n"

	if [ "${devicetype}" == "cdroms" ] ; then
		getcdromdevice 1 1 ${autoboot} || return
		mountopts="-o ro"
	else 
		getdevice || return
	fi
	
	cat << EOF
Select a stage 2 image file:

	1. ${STAGE_2_BIG_IMAGE}
	2. ${STAGE_2_SMALL_IMAGE}

EOF
	echo -n "Enter number or image file name (default=1): "
	if [ ${autoboot} -eq 1 ] ; then
		echo "1"
		text=1
	else
		read text
	fi

	if [ -z "${text}" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${text}" == "1" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${text}" == "2" ] ; then
		filename="${STAGE_2_SMALL_IMAGE}"
	else
		filename="${text}"
	fi

	echo "Using ${devicefile}:${filename}."

	if ! mkdir -p /mnt_source ; then
		echo "Can't create /mnt_source"
		return 1
	fi

	if ! mount ${mountopts} ${devicefile} "/mnt_source" ; then
		echo "Can't mount /mnt_source"
		return 1
	fi

	if ! mkdir -p /mnt_root ; then
		echo "Can't create /mnt_root"
		return 1
	fi

	if ! mount -t tmpfs -o ${TMPFS_OPTIONS} tmpfs /mnt_root ; then
		echo "Can't mount tmpfs on /mnt_root"
		return 1
	fi

	echo "Extracting 2nd stage filesystem to RAM ..."
	if ! tar ${STAGE_2_COMPRESS_ARG} -C /mnt_root -xf /mnt_source/${filename} ; then
		echo "Can't extract /mnt/source/${filename}"
		return 1
	fi

	if ! umount "/mnt_source" ; then
		echo "Can't umount /mnt_source"
		return 1
	fi

	if ! rmdir "/mnt_source" ; then
		echo "Can't remove /mnt_source"
		return 1
	fi

	export ROCK_INSTALL_SOURCE_DEV=${devicefile}
	export ROCK_INSTALL_SOURCE_FILE=${filename}
	doboot
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

	/bin/checkisomd5 --verbose ${devicefile}
	code=${?}
	if [ ${code} -eq 0 ] ; then
		echo "MD5Sum is correct."
	elif [ ${code} -eq 1 ] ; then
		echo "MD5Sum is NOT correct! Please contact the authors!"
	fi

	echo "Press Return key to continue."
	read
} # }}}

emit_udev_events() { # {{{
	/sbin/udevadm trigger
	/sbin/udevadm settle
} # }}}

input=1
[ -z "${autoboot}" ] && autoboot=0

mount / / -o remount,rw -n || echo "Can't remount / read-/writeable"
mount / / -o remount,rw  || echo "Can't remount / read-/writeable (for mount log)"
mount -t tmpfs tmpfs /tmp -o ${TMPFS_OPTIONS} || echo "Can't mount a tmpfs on /tmp"
mount -t proc proc /proc  || echo "Can't mount proc on /proc!"

# /sbin/depmod -ae

case "$( < /proc/version )" in
"Linux version 2.4."*)
	mount -t devfs devfs /dev || echo "Can't mount devfs on /dev!" ;;
"Linux version 2.6."*)
	mount -t sysfs sysfs /sys || echo "Can't mount sysfs on /sys!"

	if type -p udevd > /dev/null ; then
		mount -t tmpfs tmpfs /dev || echo "Can't mount a tmpfs on /dev!"

		cp -r /lib/udev/devices/* /dev

		echo "" > /proc/sys/kernel/hotplug
		/sbin/udevd --daemon

		# create nodes for devices already in kernel
		emit_udev_events
		mod_load_info

		# some devices (scsi...) need time to settle...
		echo "Waiting for devices to settle..."
		sleep 5
	fi ;;
esac

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
while : ; do
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
