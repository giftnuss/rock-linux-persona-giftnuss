
{
	cat <<- 'EOT'
		define(`INTEL', `Intel X86 PCs')dnl
		
		dnl CPU configuration
		dnl
		CONFIG_X86_GENERIC=y
	EOT

	if [ "$ROCKCFG_X86_BITS" = 32 ] ; then
		linux_arch="M486"
		for x in "i486		M486"		\
			 "via-c3	MCYRIXIII"	\
			 "via-c3-2	MVIAC3_2"	\
			 "pentium	M586"		\
			 "pentium-mmx	M586MMX"	\
			 "pentiumpro	M686"		\
			 "pentium2	MPENTIUMII"	\
			 "pentium3	MPENTIUMIII"	\
			 "pentium4	MPENTIUM4"	\
			 "k6		MK6"		\
			 "k6-2		MK6"		\
			 "k6-3		MK6"		\
			 "athlon	MK7"		\
			 "athlon-tbird	MK7"		\
			 "athlon4	MK7"		\
			 "athlon-xp	MK7"		\
			 "athlon-mp	MK7"
		do
			set $x
			[ "$1" = "$ROCKCFG_X86_OPT" ] && linux_arch=$2
		done
	else
		linux_arch="GENERIC_CPU"
		for x in "athlon	MK8"		\
			 "intel		MPSC"
		do
			set $x
			[ "$1" = "$ROCKCFG_X86_OPT" ] && linux_arch=$2
		done
	fi

	for x in M386 M486 MCYRIXIII MVIAC3_2 M586 M586MMX M686 MPENTIUMII \
	         MPENTIUMIII MPENTIUM4 MK6 MK7 MK8 MPSC GENERIC_CPU
	do
		if [ "$linux_arch" != "$x" ]
		then echo "# CONFIG_$x is not set"
		else echo "CONFIG_$x=y" ; fi
	done

	echo
	cat <<- 'EOT'
		dnl Memory Type Range Register support
		dnl (improvements in graphic speed ...)
		dnl
		CONFIG_MTRR=y

		dnl Some AGP support not enabled by default
		dnl
		CONFIG_AGP_AMD_8151=y
		CONFIG_AGP_SWORKS=y

		dnl PC Speaker for 2.5/6 kernel
		CONFIG_INPUT_PCSPKR=y

		dnl Other useful stuff
		dnl
		CONFIG_RTC=y
		CONFIG_INPUT_JOYSTICK=y
		CONFIG_CPU_FREQ=y
		CONFIG_HIGHMEM4G=y
		CONFIG_PARPORT_PC_FIFO=y
		CONFIG_PARPORT_1284=y

		include(`kernel-common.conf')
		include(`kernel-scsi.conf')
		include(`kernel-net.conf')
		include(`kernel-fs.conf')

		dnl NTFS for installation on esoteric notebooks where the user
		dnl might have the ISOs on an NTFS partition due to unsupported
		dnl floppy, CD, ... drives
		CONFIG_NTFS_FS=y
	EOT
} | m4 -I $base/architecture/$arch -I $base/architecture/share

