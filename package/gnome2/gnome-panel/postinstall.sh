
# merge default panel entries into the default panel gconf 
# xml-storage-cache-whatever-whocares once installed

if any_installed "gconf/schemas/panel-default-setup.entries" ; then
	GCONFDIR="`find /etc -type d -name gconf 2>/dev/null | head -n 1`"
	
	if [ -e "${GCONFDIR}/schemas/panel-default-setup.entries" ]; then
		echo "Gnome2: merging gnome-panel default entries..."
                gconftool-2 --direct \
			--config-source `gconftool-2 --get-default-source` \
			--load=${GCONFDIR}/schemas/panel-default-setup.entries
        fi
fi

