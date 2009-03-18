#!/bin/sh

# find package -type f -name '*.cache' | while read fn
# do [ -f $1/${fn%.cache}.desc ] && cp -v $fn $1/$fn; done
# cd $1; ./scripts/Create-DepDB > scripts/dep_db.txt

if [ ! -d "$1" ]; then
	echo "Usage: $0 <targetdir>"
	exit 1
fi

find package -type f -name '*.cache' | \
cut -f2,3 -d/ | sort -u | tr / ' ' | \
while read rep pkg; do
	confdir="$1/package/$rep/$pkg"
	cachedir="package/$rep/$pkg"
	descfile="$confdir/$pkg.desc"
	[ -f "$descfile" ] || continue

	if egrep '^\[(CD|CHECKDEPS)\] <COPY> ' -q $descfile
	then
		eval "$( egrep '^\[(CD|CHECKDEPS)\] <COPY> ' $descfile | sed 's,.*>,,' )"
	else
		rm -rf $confdir/*.cache
		cp $cachedir/$pkg.cache $confdir/
	fi
done

