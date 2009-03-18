
{
	cat <<- 'EOT'
		define(`MIPS', `MIPS')dnl

		CONFIG_MIPS=y
	EOT

	if [ "$ROCKCFG_MIPS_ABI" = "32" ] ; then
		cat <<- 'EOT'
			CONFIG_MIPS32=y
		EOT
	else
		cat <<- 'EOT'
			CONFIG_MIPS64=y
		EOT
	fi

	if [ "$ROCKCFG_MIPS_ENDIANESS" = "EL" ] ; then
		cat <<- 'EOT'
			CONFIG_CPU_LITTLE_ENDIAN=y
		EOT
	fi

	cat <<- 'EOT'
		include(`kernel-common.conf')
		include(`kernel-scsi.conf')
		include(`kernel-net.conf')
		include(`kernel-fs.conf')
	EOT

} | m4 -I $base/architecture/$arch -I $base/architecture/share 
