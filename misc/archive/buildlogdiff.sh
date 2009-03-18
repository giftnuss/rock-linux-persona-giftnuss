#!/bin/bash

if [ ! -f "$1" -o ! -f "$2" ]; then
	echo "Usage: $0 {logfile1} {logfile2}"
	exit 1
fi

sedprg='s/(src\.[^\/\.]+)\.[0-9\.]+/\1.XXX/g'
diff -u <( sed -r "$sedprg" $1; ) <( sed -r "$sedprg" $2; )
