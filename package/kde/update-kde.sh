#!/bin/bash

(
oldver="${1//./\.}"
newver="${2//./\.}"

cd package/kde

if [ ! "$1" -o ! "$2" ] ; then
	echo "You must specify old and new version ..."
	exit -1
fi

for x in kde* arts ; do
	[ -f $x/$x.desc ] || continue
	echo "Updating $x ..."
	sed 	-e "s,$oldver,$newver,g" \
		-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
	mv $x/$x.desc.new $x/$x.desc
done

# The version of arts is 1.x.y, but the download dir contains 3.x.y, hence
# the arts.desc is changed above and below.
x="arts"
echo "Updating $x ..."
sed 	-e "s,1\.${oldver:3},1\.${newver:3},g" \
	-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
mv $x/$x.desc.new $x/$x.desc

# Likewise for kdevelop, but the version number is 3.3.x.
x="kdevelop"
echo "Updating $x ..."
sed 	-e "s,3\.3\.${oldver:6},3\.3\.${newver:6},g" \
	-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
mv $x/$x.desc.new $x/$x.desc
)
