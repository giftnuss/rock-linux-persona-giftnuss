#!/bin/sh
# create the list for cpio-entries to be used by gen_cpio_init
# shall be called by mkinitramfs.sh only.
# sources each file in ./build.d/

if [ -z "$irfs_libexec_functions" ]
then
	echo "sorry - some required functions are not declared."
	echo "you need to source the 'functions' script first."
	echo "try: source `dirname $0`/functions"
	exit 1
fi

if [ -z "$builddir" ]
then
	echo "\$builddir variable is not set."
	exit 1
fi

if [ -z "$TMPDIR" ]
then
	echo "\$TMPDIR variable is not set."
	exit 1
fi

mkdir -pv $TMPDIR/targetdir

# now go through the build.d directory
for x in $builddir/[0-9][0-9]*
do
	echo
	echo "sourcing $x ($scriptopt)" >&2
	# use the same environment for each script
	( cd $TMPDIR/targetdir ; eval $scriptopt ; . $x )
done | sort -u
