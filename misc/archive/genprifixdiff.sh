#!/bin/bash

# Usage example:
# for x in [0-9]*.patch; do bash genprifixdiff.sh ${x%.patch}; done

if [ -f fixdiff_$1.patch ]; then
	echo "Found existing fixdiff for $1!"
	exit 1
fi

cp $1.patch $1.patch_new

for descfile in $( lsdiff $1.patch | grep '\.desc$'; )
do
	currpri=$( grep '^\[P\]' $descfile | sed 's, *$,,; s,.* ,,'; )
	if [ -n "$currpri" ]; then
		perl -i -pe "
			if (not \$done) {
				\$gotit = 1 if m,$descfile,;
				\$done = 1 if \$gotit and s/(\[P\].*)([0-9]{3}\.[0-9]{3})/\${1}$currpri/;
			}
		" $1.patch_new
	fi
done

{
	echo "Generated using genprifixdiff.sh"
	diff -u $1.patch $1.patch_new
} > fixdiff_$1.patch

rm -f $1.patch_new

exit 0

