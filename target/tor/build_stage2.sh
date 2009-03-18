#!/bin/bash
#
set -e
#
read ROCKATE_VERSION < $base/target/$target/VERSION
echo_header "Creating 2nd stage filesystem:"
mkdir -p $disksdir/2nd_stage
cd $disksdir/2nd_stage
mkdir -p ramdisk usr/X11R7 var/state/dhcp
ln -s X11R7 usr/X11
ln -s X11R7 usr/X11R6
#
echo_status "Extracting the packages archives."
if [ "${ROCKCFG_TARGET_TOR_SIZE}" == "ultimate" ] ; then
	for x in $( ls ../../pkgs/*.tar.bz2 )
	do
		echo_status "\`- Extracting ${x##*/} ..."
		tar --use-compress-program=bzip2 --force-local -xpf $x
	done
elif [ "${ROCKCFG_TARGET_TOR_SIZE}" == "all" ] ; then
	for x in $( ls ../../pkgs/*.tar.bz2 | \
		grep -v ':doc.tar.bz2' | grep -v ':dev.tar.bz2' )
	do
		echo_status "\`- Extracting ${x##*/} ..."
		tar --use-compress-program=bzip2 --force-local -xpf $x
	done
elif [ "${ROCKCFG_TARGET_TOR_SIZE}" == "packages" ] ; then
	for x in $( sed 's,^\(.*\)$,../../pkgs/\1.tar.bz2,g' $base/target/tor/needed_pkgs )
	do
		echo_status "\`- Extracting ${x##*/} ..."
		tar --use-compress-program=bzip2 --force-local -xpf $x
	done
elif [ "${ROCKCFG_TARGET_TOR_SIZE}" == "files" ] ; then
	read total name < <( wc -l $base/target/tor/needed_files )
	current=0
	while read file ; do
		current=$(($current+1))
		echo_status "\`- $((${current}00/$total))% copying $file"
		mkdir -p ${file%/*}
		if [ -L $base/build/$ROCKCFG_ID/$file ] ; then
			t="$( readlink $base/build/$ROCKCFG_ID/$file )"
			ln -sf $t $file
		else
			cp -ap $base/build/$ROCKCFG_ID/$file $file
		fi
	done < $base/target/tor/needed_files
fi
#
if [ "${ROCKCFG_TARGET_TOR_SIZE}" != "ultimate" ] ; then
	echo_status "Saving boot/* - we do not need this on the 2nd stage ..."
	rm -rf ../boot ; mkdir ../boot
	mv boot/* ../boot/
else
	mkdir ../boot
	cp -r boot/* ../boot/
fi
#
echo_status "Remove the stuff we do not need ..."
rm -rf usr/src var/adm
#
# TODO finish-package!!
echo_status "Running ldconfig to create links ..."
ldconfig -r .
echo_status "Running depmod for target system ..."
depmod -b $PWD -F ../boot/System.map `ls ../boot/vmlinuz_* | sed -e 's,\.\./boot/vmlinuz_,,'`
echo_status "Running mkfontscale/mkfontdir and fc-cache ..."
for dir in usr/X11R7/lib/X11/fonts/* ; do
	[ -d $dir ] || continue
	mkfontscale $dir
	mkfontdir $dir
	fc-cache -v $dir
done
#
echo_status "replacing some vital files for live useage ..."
cp -f $base/target/$target/fixedfiles/inittab etc/inittab
cp -f $base/target/$target/fixedfiles/login-shell sbin/login-shell
# this got drop once, so we ensure it's +xed.
chmod 0755 sbin/login-shell
cp -f $base/target/$target/fixedfiles/system etc/rc.d/init.d/system
cp -f $base/target/$target/fixedfiles/xorg.conf etc/X11/xorg.conf
#
echo_status "Creating home directories and users..."
mkdir -p home/{rocker,root}
chown 1000:100 home/rocker
#
if [ -d usr/lib/firefox-* ] ; then
	echo_status "Adding Firefox Plugins..."
	read v ffversion < <( grep '^.V. ' $base/package/x11/firefox/firefox.desc )
	grep xpi $base/target/$target/download.txt | cut -f2 -d' ' | while read xpi ; do
		echo "- $xpi"
		tmp="$(mktemp -d)"
		cd $tmp
		unzip $base/download/mirror/${xpi:0:1}/${xpi}
		sed -e "s,<em:maxVersion>.*</em:maxVersion>,<em:maxVersion>${ffversion}</em:maxVersion>,g" -i install.rdf
		sed -e "s,em:maxVersion=\".*\",em:maxVersion=\"${ffversion}\",g" -i install.rdf
		read id < <( grep "em:id" install.rdf | head -n 1 | sed 's,^.*\({.*}\).*$,\1,g' )
		cd -
		mv $tmp "usr/lib/firefox-$ffversion/extensions/${id}"
		find usr/lib/firefox-$ffversion/extensions/${id} -type d -exec chmod 0755 {} \;
		find usr/lib/firefox-$ffversion/extensions/${id} ! -type d -exec chmod 0644 {} \;
	done

	echo_status "Setting FireFox defaults..."
	#pref("network.proxy.http", "localhost");
	tmp="$(mktemp)"
	grep pref $base/target/$target/fixedfiles/firefox.js | while read line ; do
		item="${line#pref(\"}"
		item="${item%%\",*}"
		grep -v "\"${item}\"" usr/lib/firefox-$ffversion/defaults/pref/firefox.js > $tmp
		echo "${line}" >> $tmp
		cat $tmp > usr/lib/firefox-$ffversion/defaults/pref/firefox.js
	done
	rm -f $tmp
	cp $base/target/$target/fixedfiles/bookmarks.html usr/lib/firefox-$ffversion/defaults/profile/bookmarks.html
fi

sed -i -e 's,root:.*,root::0:0:root:/home/root:/bin/bash,' etc/passwd
sed -i -e 's,root:.*,root:$1$9KtEb9vt$IDoD/c7IG5EpCwxvBudgA:13300::::::,' etc/shadow
echo 'rocker:x:1000:100:ROCK Live CD User:/home/rocker:/bin/bash' >> etc/passwd
echo 'rocker:$1$b3mL1k/q$zneIjKcHqok1T80fp1cPI1:13300:0:99999:7:::' >> etc/shadow
sed -i -e 's,wheel:x:10:,wheel:x:10:rocker,' etc/group
sed -i -e 's,video:x:16:,video:x:16:rocker,' etc/group
sed -i -e 's,sound:x:17:,sound:x:17:rocker,' etc/group
sed -i -e 's,cdrom:x:29:,cdrom:x:29:rocker,' etc/group

# 
echo_status "activating shadowfs through /etc/ld.so.preload"
echo "/usr/lib/libcowfs.so" > etc/ld.so.preload
#
echo_status "adding a few additional files"
cp -v $base/download/mirror/t/tor_aliases_v5 etc/profile.d
echo ROCKate > etc/HOSTNAME

echo "export WINDOWMANAGER=\"/usr/bin/icewm-session\"" > etc/profile.d/windowmanager
echo "if [ \"\${TERM}\" == \"xterm\" ] ; then export TERM=\"xterm-color\" ; fi" > etc/profile.d/xterm-color
echo "export XDM=\"/usr/X11R7/bin/xdm\"" > etc/conf/xdm
echo "#!/bin/bash" > sbin/startx_on_boot
echo "su - rocker -c \". /etc/profile; /usr/X11R7/bin/startx\"" >> sbin/startx_on_boot
chmod +x sbin/startx_on_boot

echo "127.0.0.1		ROCKate" >> etc/hosts

cp $base/target/tor/fixedfiles/irssi_config etc/irssi.conf
chmod 644 etc/irssi.conf

mkdir -p etc/tor
cp $base/target/tor/fixedfiles/torrc etc/tor/torrc

cp $base/target/tor/fixedfiles/mod_rockate.sh etc/stone.d/
cp $base/target/tor/fixedfiles/*.desktop usr/share/applications

cp $base/download/mirror/r/rockate_*jpg usr/share/icewm/
cp $base/target/tor/fixedfiles/icewm_menu usr/share/icewm/menu
cp $base/target/tor/fixedfiles/rock-menu usr/share/icewm/rock-menu
chmod +x usr/share/icewm/rock-menu
chroot . /usr/share/icewm/rock-menu

echo ${ROCKATE_VERSION} > etc/ROCKATE_VERSION
# temporary fl_wrapper addition for dependency checking
#echo "export FLWRAPPER_WLOG=\"/tmp/fl_wrapper.wlog\"" >> etc/profile
#echo "export FLWRAPPER_RLOG=\"/tmp/fl_wrapper.rlog\"" >> etc/profile
#echo "touch \${FLWRAPPER_WLOG} \${FLWRAPPER_RLOG}" >> etc/profile
#echo "chmod 666 \${FLWRAPPER_WLOG} \${FLWRAPPER_RLOG}" >> etc/profile
#cp "$base/build/$ROCKCFG_ID/ROCK/tools.native/lib/fl_wrapper.so" lib/
#echo "/lib/fl_wrapper.so" >> etc/ld.so.preload

if [ "${ROCKCFG_TARGET_TOR_SIZE}" == "files" ] ; then
	echo_status "Compressing binaries"
	files="`find bin sbin usr/bin usr/sbin usr/X11/bin -type f -print0 | xargs -0 file | grep ELF | cut -f1 -d:`"
	$base/build/$ROCKCFG_ID/usr/bin/upx2 --brute $files < /proc/$$/fd/0 > /proc/$$/fd/1 2> /proc/$$/fd/2 || true
fi
touch etc/$( tr [:lower:] [:upper:] <<< "${ROCKCFG_TARGET_TOR_SIZE}" )

echo_status "Creating 2nd_stage.img.z image... (this takes some time)... "
cd .. ; mksquashfs 2nd_stage 2nd_stage.img.z -noappend > /dev/null 2>&1
