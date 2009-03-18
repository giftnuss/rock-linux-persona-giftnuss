#!/bin/bash

# Subversion has really big ".svn" subdirs. This has much better performance
# than the "find ... ! -path '*/.svn*' ! -path '*/CVS*' ..." used earlier
# in various places. Never use this with -depth! Instead pipe the output thru
# "tac" or "sort -r".

dirs=""

while [ "${1##[-(!]*}" ]
do
	# the pathnames hopefully don't contain spaces
	dirs="$dirs$1 "
	shift
done

[ $# -eq 0 ] && set -- -true

find $dirs \( -name .svn -o -name CVS \) -prune -false -o \
	! -name .svn ! -name CVS \( "$@" \)

