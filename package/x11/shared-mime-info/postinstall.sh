#!/bin/sh

update_mime_db() {
	local dir

	for dir in $@ ; do
		if [ -d $dir -a -d $dir/packages ] ; then
			update-mime-database -V $dir
		fi
	done
}

[ -z "$XDG_DATA_DIRS" ] && XDG_DATA_DIRS="/usr/local/share:/usr/share"

if [ "$install_checks_true" = 1 ] ; then
	update_mime_db ${XDG_DATA_DIRS//:/ } /opt/*/share/mime
else
	update_mime_db $( all_installed ".*/share/mime/.*" | sed -e "s,\(/share/mime/\).*,\1," | sort -u )
fi
