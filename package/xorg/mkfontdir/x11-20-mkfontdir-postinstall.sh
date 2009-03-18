#!/bin/sh

# mkfontscale has to be run before mkfontdir.

print_status=1
if any_touched 'usr/X11R7/lib/X11/fonts/' ; then
	for dir in /usr/X11R7/lib/X11/fonts/* ; do
		[ -d $dir ] || continue
		[ $print_status = 1 ] && \
			{ echo "Running mkfontdir ..." ; print_status=0 ; }
		echo -n "$dir "
		mkfontdir $dir
	done
	[ $print_status = 0 ] && echo
fi
unset dir print_status
