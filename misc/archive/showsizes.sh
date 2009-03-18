#!/bin/bash

if [ $1 ] ; then
	case $1 in
	-help)
		echo "Useage: $0 [ -path <part of a path> ]"
		exit 1;
		;;
	-path)
		FLISTGREP="$2";
		shift; shift;
		;;
	esac
fi

if [ -n "$FLISTGREP" ] ; then
	FILES=`grep -l -- "$FLISTGREP" /var/adm/flists/* | sed -e 's,^/var/adm/flists,/var/adm/packages,'`
else
	FILES=`ls /var/adm/packages/*`
fi

grep '^Package Size: ' $FILES | sed -e 's,^.*/\(.*\):Package Size: \(.*\) MB.*,\2 \1,' | sort -n 
