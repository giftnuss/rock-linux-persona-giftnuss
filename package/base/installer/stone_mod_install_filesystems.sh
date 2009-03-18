#!/bin/bash

MAIN_MENU="'Setup Filesystems' 'main_setup_filesystems' ${MAIN_MENU}"

DISKS_MENU=""
# Additional items to show in the disk menu (main_setup_filesystems)
# Intended for setup of RAID or similiar

ADDITIONAL_DISK_DETECTOR=""
# Functions to call from main_setup_filesystems for additional disk detections
# Intended for listing existing RAID arrays

PARTITIONING_MENU=""
# STONE formatted menu for partitioning a harddisk
# use DISK as parameter

MKFS_PROGRAMS=""
# STONE formatted menu for filesystem creation
# use PART as parameter

REREAD_INFORMATION=0
# If 1, then main_setup_filesystems is started from scratch
main_edit_part(){
	local partition="${1}"

	realmenu="${MKFS_PROGRAMS//PART/${partition}}"
	local run=1
	while [ ${run} -eq 1 ] ; do
		eval gui_menu MAIN_EDIT_PART "'Create a filesystem'" ${realmenu}
		if [ "${?}" == "1" ] ; then	# Cancel was pressed
			run=0
		else
			REREAD_INFORMATION=1
		fi
	done
}

main_edit_disk(){
	local disk="${1}"

	realmenu="${PARTITIONING_MENU//DISK/${disk}}"
	local run=1
	while [ ${run} -eq 1 ] ; do
		eval gui_menu MAIN_EDIT_DISK "'Partitioning ${disk}'" ${realmenu}
		if [ "${?}" == "1" ] ; then	# Cancel was pressed
			run=0
		else
			REREAD_INFORMATION=1
		fi
	done
}

main_mount_do_mount(){
	local disk="${1}"
	local mountpoint="${2}"

	if [ ! -e "/mnt/target/${mountpoint}" ] ; then
		gui_yesno "'${mountpoint}' does not exist. Create it?"
		rval="${?}"
		if [ "${rval}" == "0" ] ; then
			mkdir -p "/mnt/target/${mountpoint}"
		else
			return 1
		fi
	fi

	if [ ! -d "/mnt/target/${mountpoint}" ] ; then
		gui_message "'${mountpoint}' exists but is not a directory!"
		return 1
	fi

	numfiles=0
	while read file ; do
		numfiles=$(( ${numfiles} + 1 ))
	done < <( ls "/mnt/target/${mountpoint}" )
	if [ ${numfiles} -gt 2 ] ; then		# . and .. directories only is considered empty
		gui_yesno "'${mountpoint}' contains files! Mount anyway?"
		rval="${?}"
		if [ "${rval}" == "1" ] ; then
			return 1
		fi
	fi

	mount "${disk}" "/mnt/target/${mountpoint}"

	REREAD_INFORMATION=1
}

main_mount_partition_other(){
	local disk="${1}"

	gui_input "Where do you want to mount '${disk}'?" '/data' mountpoint
	[ -z "${mountpoint}" ] && return 1

	main_mount_do_mount "${disk}" "${mountpoint}"

	return 0
}

main_mount_partition(){
	local disk="${1}"
	local mountpoint="${2}"
	local fstype="${3}"

	menu=""
	if [ "${mountpoint}" == "nowhere" ] ; then
		if [ "${fstype}" == "Swap" ] ; then
			gui_yesno "Do you want to activate the SWAP on '${disk}'"
			rval=${?}
			if [ ${rval} -eq 0 ] ; then
				swapon "${disk}"
				REREAD_INFORMATION=1
			fi
		else
			for x in / /boot /home /var /usr /srv ; do
				menu="${menu} 'Mount on ${x}' 'main_mount_do_mount ${disk} ${x#}'"
			done

			menu="${menu} 'Other mountpoint' 'main_mount_partition_other \"${disk}\"'"

			eval gui_menu MAIN_MOUNT_PARTITION "'Where do you want to mount ${disk}?'" ${menu}
		fi
	elif [ "${mountpoint}" == "SWAP" ] ; then
		gui_yesno "Do you want to deactivate the SWAP on '${disk}'?"
		rval=${?}
		if [ ${rval} -eq 0 ] ; then
			swapoff "${disk}"
			REREAD_INFORMATION=1
		fi
	else
		gui_yesno "Do you want to umount '${disk}' from '${mountpoint}'?"
		rval=${?}
		if [ ${rval} -eq 0 ] ; then
			umount "/mnt/target/${mountpoint}"
			REREAD_INFORMATION=1
		fi
	fi
}

main_setup_filesystems_add_part(){
	# is a partition
	local disk="${1}"
	local size="${2}"
	local tmp="$(mktemp)"

	if [ -z "${size}" ] ; then
		size="$( blockdev --getsize64 ${disk} )"
	fi

 	disktype "${disk}" > "${tmp}"
	read fstype rest < <( grep " file system" "${tmp}" )

	grep -q "^Linux swap" "${tmp}" && fstype="Swap"
	grep -q 'RAID set UUID' "${tmp}" && fstype="RAID"
	fstype="${fstype:-Unknown}"
	if grep -q 'Type 0x05 (Extended)' "${tmp}" && [ ${size} -eq 1024 ] ; then
		continue
		# Is a DOS extended partition. We don't want this to show up here
	fi
	DISKS="${DISKS} ' ${fstype} Partition ($(( ${size} / 1024 / 1024)) MB)' 'main_edit_part ${disk}'"
	realdisk="${disk}"
	while [ -L "${realdisk}" ] ; do
		realdisk="$( readlink -f ${disk} )"
	done
	mountpoint="$( mount | grep ^${realdisk} | cut -f 3 -d' ' )"
	[ -n "${mountpoint}" ] && mountpoint="${mountpoint}/";
	mountpoint="${mountpoint#/mnt/target}"
	[ -n "${mountpoint}" ] && mountpoint="/${mountpoint#/}"	# necessary to do this way because rootfs will be "/mnt/target"
	swapon -s | grep -q ^${realdisk} && mountpoint="SWAP"
	if [ -z "${mountpoint}" ] ; then
		if [ "${fstype}" == "Swap" ] ; then
			DISKS="${DISKS} '  Inactive Swap'"
		elif [ "${fstype}" == "RAID" ] ; then
			DISKS="${DISKS} '  Part of a RAID'"
		else
			DISKS="${DISKS} '  Not mounted'"
		fi
	elif [ "${mountpoint}" == "SWAP" ] ; then
		DISKS="${DISKS} '  Active Swapspace'"
	else
		DISKS="${DISKS} '  Mounted on ${mountpoint}'"
	fi
	DISKS="${DISKS} 'main_mount_partition \"${disk}\" \"${mountpoint:-nowhere}\" \"${fstype}\"'"
	rm -f "${tmp}"
}

main_setup_filesystems() {
	DISKS=""
	# Array of disks, /dev/disk/by-id/ata-* (without partitions!), formerly /dev/[hs]d[a-z]
	# Format: DISKS="/dev/sda 'SCSI Disk (description; size)'"
	for disk in /dev/disk/by-id/* ; do
		type="${disk##*/}"
		type="${type%%-*}"
		if [ "${type}" == "ata" -o "${type}" == "usb" -o "${type}" == "sata" -o "${type}" == "scsi" ] ; then
			tmp="$(mktemp)"
			disktype "${disk}" > "${tmp}"
			if [ "${type}" == "ata" -o "${type}" == "sata" -o "${type}" == "scsi" ] ; then
				hdparm -i "${disk}" >> "${tmp}"
				model="$(sed -e"s:Model=*\(.*\), FwRev.*:\1:p ; d" < ${tmp})"
				serial="$(sed -e"s:.*SerialNo=*\(.*\):\1:p ; d" < ${tmp})"
			elif [ "${type}" == "usb" ] ; then
				model="USB Device"
				serial="${disk%-*}"
				serial="${serial##*-}"
			else
				type="UNKNOWN"
				unset model serial
			fi
			type=$( echo $type | tr '[:lower:]' '[:upper:]')

			if [ "${disk%-part*}" != "${disk}" ]  ; then
				# is a partition
				main_setup_filesystems_add_part "${disk}" ""
			else
				# is a disk
				if [ -z "${size}" ] ; then 
					size=$( blockdev --getsize64 ${disk} )
				fi
				DISKS="${DISKS} '${type} Disk (${model:-Unknown Model} - ${serial:-Unknown Serial Number} - $(( ${size} / 1024 / 1024 )) MB)' 'main_edit_disk ${disk}'"
			fi
			rm -f "${tmp}"
		else
			# unknown type
			DISKS="${DISKS} 'Unknown Type of disk (${disk}) Please contact the Developers!' ''"
		fi
	done

	for x in ${ADDITIONAL_DISK_DETECTOR} ; do
		eval ${x}
	done

	local run=1
	while [ ${run} -eq 1 ] ; do
		eval gui_menu SETUP_FILESYSTEMS '"Filesystem Setup"' ${DISKS_MENU} ${DISKS_MENU:+"'' ''"} "${DISKS}" "'' ''" ${PARTITIONS}
		if [ "${?}" == "1" ] ; then	# Cancel was pressed
			run=0
		fi
		if [ ${REREAD_INFORMATION} -eq 1 ] ; then
			run=0
		fi
	done
	if [ ${REREAD_INFORMATION} -eq 1 ] ; then
		REREAD_INFORMATION=0
		main_setup_filesystems
	fi
}

for subscript in ${SETUPD}/mod_install_*.sh ; do
	subscript="${subscript#${SETUPD}/}"
	if [ "${subscript%_*}" == "mod_install_filesystems" ] ; then
		. ${SETUPD}/${subscript}
	fi
done
