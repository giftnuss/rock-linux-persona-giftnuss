#!/bin/sh

export PATH="/bin:/usr/bin:/sbin:/usr/sbin"

if type -p gzip > /dev/null ; then
	umount -d /old_root ; rmdir /old_root
else
	PATH="$PATH:/old_root/bin"
	for x in /old_root/* ; do
		rmdir $x 2> /dev/null || rm -f $x 2> /dev/null
	done
fi
grep -v "^rootfs " /proc/mounts > /etc/mtab
freeramdisk /dev/rd/* 2> /dev/null

mkdir -p /lib/modules/$( uname -r )
echo -n >> /lib/modules/$( uname -r )/modules.dep

setterm -blank 0 -powersave off -powerdown 0

echo
echo '  ******************************************************************'
echo '  *         Welcome to the ROCK Linux 2nd stage boot disk.         *'
echo '  ******************************************************************'
echo
echo "This is a small linux distribution, loaded into your computer's memory."
echo "It has everything needed to install ROCK Linux, restore an old installation"
echo "or perform some administrative tasks."

for x in /etc/setup-*.sh /setup/setup.sh ; do
   if [ -f "$x" ] ; then
      echo ; echo "Running $x ..." ; sh $x
      echo "Setup script $x finished."
   fi
done

echo
ttydevs=""

if [ -z "$autoboot" ]; then
	echo "Enter the names of all terminal devices (e.g. 'vc/1' or 'tts/0')."
	echo -n "An empty text stands for vc/1 - vc/6: "; read ttydevs
fi

if [ -z "$ttydevs" ]; then
	ttydevs="vc/1 vc/2 vc/3 vc/4 vc/5 vc/6"
fi

if [[ "$ttydevs" = *tts/* ]] ; then
	echo -n "Connection speed in Baud (default: 9600): " ; read baud
	[ -z "$baud" ] && baud=9600
else
	baud=38400
fi

echo
echo 'Just type "stone" now if you want to make a normal installation of a ROCK'
echo -n 'Linux build '
if type -p dialog > /dev/null ; then
	echo '(or type "stone -text" if you prefer non-dialog based menus).'
else
	echo '(only the text interface is available).'
fi

if [ -z "$autoboot" ]; then
	echo -e '#!/bin/sh\ncd ; exec /bin/sh --login' > /sbin/login-shell
else
	cat <<- EOT > /sbin/login-shell
		#!/bin/bash

		cd
		case "\$( tty )" in
		  /dev/vc/1)
		    echo "Running 'stone' now.."
		    /bin/sh --login -c "stone"
		    echo -e '#!/bin/sh\\ncd ; exec /bin/sh --login' > /sbin/login-shell
		    exit 0
		    ;;
		  *)
		    exec /bin/sh --login
		esac
	EOT
fi
chmod +x /sbin/login-shell

for x in $ttydevs ; do
   ( ( while : ; do agetty -i $baud $x -n -l /sbin/login-shell ; done ) & )
done

exec < /dev/null > /dev/null 2>&1
while : ; do sleep 1 ; done
