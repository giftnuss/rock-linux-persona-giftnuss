#!/bin/bash

(
oldver="${1//./\.}"
newver="${2//./\.}"

cd package/kde4

if [ ! "$1" -o ! "$2" ] ; then
	echo "You must specify old and new version ..."
	exit -1
fi

for x in kde* ; do
	[ -f $x/$x.desc ] || continue
	echo "Updating $x ..."
	sed 	-e "s,$oldver,$newver,g" \
		-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
	mv $x/$x.desc.new $x/$x.desc
done

# Likewise for kdevelop, but the version number is 3.3.x.
# x="kdevelop"
# echo "Updating $x ..."
# sed 	-e "s,3\.3\.${oldver:6},3\.3\.${newver:6},g" \
# 	-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
# mv $x/$x.desc.new $x/$x.desc
)
