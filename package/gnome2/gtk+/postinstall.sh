
/D_prefix/bin/gdk-pixbuf-query-loaders \
    > /D_sysconfdir/gtk-2.0/gdk-pixbuf.loaders

# update gnome2 icon cache files for gnome2 directories that
# contain index.theme files

print_status=1
all_installed "gnome2/share/.*/index.theme$" |
while read IDX; do
	[ $print_status = 1 ] && \
		{ echo "Gnome 2 icon cache files: running gtk-update-icon-cache..."
			print_status=0 ; }

	gtk-update-icon-cache "${IDX%index.theme}"
done

# update gnome2 icon cache files for icon directories
# that don't contain an index.theme file

all_touched "gnome2/share/.*/icons" |
while read FILE; do
	DIR="${FILE%icons/*}icons"
	[ ! -e "$DIR/index.theme" ] && 
	{
		[ $print_status = 1 ] && \
			{ echo "Gnome 2 icon cache files: running gtk-update-icon-cache..."
				print_status=0 ; }

		gtk-update-icon-cache --ignore-theme-index "$DIR"
	}
done

all_touched "gnome2/share/icons/hicolor" |
while read FILE; do
	DIR="${FILE%hicolor/*}hicolor"
	[ ! -e "$DIR/index.theme" ] &&
	{
		[ $print_status = 1 ] && \
			{ echo "Gnome 2 icon cache files: running gtk-update-icon-cache..."
				print_status=0 ; }

		gtk-update-icon-cache --ignore-theme-index "$DIR"
	}
done
