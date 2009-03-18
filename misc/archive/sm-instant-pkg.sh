#!/bin/bash
#
# Usage example: sh misc/archive/sm-instant-pkg.sh 'Clifford Wolf' m4 

if [ "$1" == "EDITOR" ]; then
	(
		cd "$2"
		echo; echo 'Version change:'
		svn diff package/*/$3/*.desc | grep '^.\[V\]'
		echo; echo 'Full diff:'
		svn diff package/*/$3/*.desc
	) >> $4
	(
		cd "$2"
		echo
		echo "$SM_INSTANT_PKG_NAME:"
		pkgver=`grep '^\[V\]' package/*/$3/*.desc | awk '{ print $2; }'`
		echo "	Updated $3 ($pkgver)"
	) > $4.1
	cat $4.1 $4 > $4.2
	mv $4.2 $4; rm $4.1
	exec vi $4
fi

export SM_INSTANT_PKG_NAME="$1"
shift

for pkg; do
	export SVN_EDITOR="bash $PWD/misc/archive/sm-instant-pkg.sh EDITOR '$PWD' '$pkg'"
	sm instant package/*/$pkg
done

