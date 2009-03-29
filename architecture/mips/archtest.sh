
case "$ROCKCFG_MIPS_ENDIANESS" in
    EL)
    	arch_bigendian=no
	arch_endianess="el" ;;
    EB)
    	arch_bigendian=yes
	arch_endianess="" ;;
esac

case "$ROCKCFG_MIPS_ABI" in
    *32)
	arch_machine=mips 
	arch_target="${arch_machine}${arch_endianess}-unknown-linux-gnu" ;;
    *64) 
	arch_machine=mips64 
	arch_target="${arch_machine}${arch_endianess}-unknown-linux-gnu"
	arch_target32="mips${arch_endianess}-unknown-linux-gnu"
	BUILD32="-mabi=32"
	BUILD64="-mabi=$ROCKCFG_MIPS_ABI"
	;;
esac
