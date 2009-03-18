if [ x"$ROCKCFG_PKG_LINUX_BOOTSPLASH" == x'1' ]; then
	for x in CONFIG_{FRAMEBUFFER_CONSOLE,FBCON_SPLASHSCREEN,BOOTSPLASH}; do 
		 sed -i "/$x/d" $1
		 echo "$x=y" >> $1
	done
else
	for x in CONFIG_{FRAMEBUFFER_CONSOLE,FBCON_SPLASHSCREEN,BOOTSPLASH}; do 
		 sed -i "/$x/d" $1
 	done
fi 
