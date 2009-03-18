#!/bin/bash
#
# AutoPCH: Automatically use pre-compiled headers
#
# Simply use this script instead of calling g++ directly.
# This is a dirty hack. So don't wonder if it does not work
# out of the box with every package.
#
# example using kdegames:
# -----------------------
#
# time make CXX="autopch"
# real    30m41.945s
# user    25m30.924s
# sys     3m9.300s
#
# without autopch:
# real    42m59.061s
# user    36m50.630s
# sys     2m41.806s


cxx="${AUTOPCHCXX:-g++}"
[ "$cxx" == "$0" ] && exit 2

cppfile="$( echo " $* " | sed -r 's,((.* )([^ ]*\.(cc|cp|cpp|CPP|cxx|c\+\+|C))) .*,\3,' )"
cppdir="$( echo "$cppfile" | sed -r 's,[^/]*$,,'; )"
cppargs="$( echo " $* " | sed -r 's, ([^- ]|-[MCSEco])[^ ]*,,g'; )"

echo "AutoPCH> $cxx $*" >&2
echo "AutoPCH - cppargs> \"$cppargs\"" >&2
echo "AutoPCH - cppdir, cppfile> \"$cppdir\", \"$cppfile\"" >&2

if [ ! -f "$cppfile" ]; then
	exec $cxx "$@"
	exit 1
fi

autopch="$cppdir${cppdir:+/}autopch"
if [ ! -f "${autopch}.h" -a ! -f "${autopch}_oops.h" ]; then
	{
		echo "#ifndef _AUTOPCH_H_"
		echo "#define _AUTOPCH_H_"
		echo "#warning AutoPCH: THEWARNING"
		[ -f "${autopch}_incl.h" ] && cat "${autopch}_incl.h"
		sed -r '/^( |	)*#( |	)*(include|if|endif|define|undef)/ {
			: label /\\$/ { N ; P ; b label ; } ; p
		} ; d' "$cppdir"${cppdir:+/}*.{cc,cp,cpp,CPP,cxx,c++,C} 2&>1
# \
#		| egrep -v "[<\"](${AUTOPCHEXCL:-autopch.h})[\">]"
		echo "#endif /* _AUTOPCH_H_ */"
	} > "${autopch}.h.plain"
	sed 's,THEWARNING,New pre-compiled header.,' \
		< "${autopch}.h.plain" > "${autopch}.h"
	# Precompile the autopch.h file
	echo "exec $cxx -I. $cppargs -x c++ -c \"${autopch}.h\"" \
		> "${autopch}.sh"
	if ! sh "${autopch}.sh" ; then
		mv -f "${autopch}.h" "${autopch}_oops.h"
	fi
	sed 's,THEWARNING,Pre-compiled header not used!,' \
		< "${autopch}.h.plain" > "${autopch}.h"
fi

if test -f ${autopch}.h && ! $cxx -include ${autopch}.h "$@"; then
	echo "AutoPCH: Fallback to non pre-compiled headers!" >&2
	exec $cxx "$@"
	exit 1
fi
exit 0
