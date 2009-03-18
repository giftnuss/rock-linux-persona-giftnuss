#!/bin/sh

if any_touched "usr/share/rock-registry/wm/" ; then
	confprefix=/usr/share/config/kdm/
	sessprefix=/usr/share/apps/kdm/sessions/
	sessions="default,failsafe"

	echo "Creating kdm session scripts from ROCK wm registry ..."

	cat $confprefix/Xsession.pre > $confprefix/Xsession

	for x in /usr/share/rock-registry/wm/* ; do
		[ -f "$x" ] || continue
		. $x

		short="`basename $x`"
		echo -n "  $name ($short) ..."

		sessions="$sessions,$short"

		# adding the case entry ... damn kdm ...
		echo -e "    $short)\n	exec $exec\n	;;" \
			>> $confprefix/Xsession
	
		# Session Types are now outside kdmrc as .desktop files
		if [ -z "$(grep -R $(basename $exec) $sessprefix 2>/dev/null)" ] ; then
				cat >$sessprefix/$short.desktop <<EOS
[Desktop Entry]
Type=XSession
Exec=$exec
TryExec=$exec
Name=$name
EOS
		 	echo " $short.desktop ..."
		else
			echo
		fi
	done

	cat $confprefix/Xsession.post >> $confprefix/Xsession
	chmod +x $confprefix/Xsession

	unset x confprefix sessprefix sessions
fi

#echo "Adapting the kdmrc ..."
#sed "s/SessionTypes=.*/SessionTypes=$sessions/" $confprefix/kdmrc > $confprefix/kdmrc.new
#mv $confprefix/kdmrc.new $confprefix/kdmrc
 
