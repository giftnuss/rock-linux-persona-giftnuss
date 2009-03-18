
if any_installed "usr/share/xml/[^/]*/catalog.xml" ; then
	echo "Recreating /etc/xml/catalog file.."
	( cd /etc/xml && ./update_catalog.sh; )
fi

