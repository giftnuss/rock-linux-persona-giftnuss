if [ x"$ROCKCFG_PKG_LINUX_MISDN" == x'1' ]; then
   	for x in AVM_FRITZ HFCPCI HFCMULTI HFCUSB SPEEDFAX W6692 DSP LOOP; do 
		sed -i "/CONFIG_MISDN_$x.*/d" $1
   		echo "CONFIG_MISDN_$x=y" >>  $1
   	done 
else
   	for x in AVM_FRITZ HFCPCI HFCMULTI HFCUSB SPEEDFAX W6692 DSP LOOP; do 
		sed -i "/CONFIG_MISDN_$x.*/d" $1
 	done
fi 
