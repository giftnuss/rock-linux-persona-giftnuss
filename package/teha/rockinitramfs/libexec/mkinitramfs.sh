#!/bin/sh

# create initramfs image by using gen_cpio_init
# (no need for root privileges)
#
# see ./build.d/ to see how the content is created!

export PATH=$PATH:/sbin:/bin:/usr/bin:/usr/sbin

k_ver=`uname -r`

usage() {
	cat <<-EOF
	mkinitramfs - create initramfs image by using gen_cpio_init

	typical use:
	mkinitramfs [ -r KERNEL_VERSION ] [ -m MODULES_DIR ] [ -o OUTPUT_FILE ]

	If no options are given the following defaults apply:
		mkinitramfs -r $k_ver -m $mod_origin -o $outfile

	Options:
		-r                 Specify kernel version to use for modules dir

		-m                 Specify directory where to search for kernel modules

		-o                 Specify location of output file

		-p VAR=val         Pass some variable definition to the build.d scripts

		-O                 output file list to given location

		--build-dir        alternate directory for /lib/rock_initramfs/build.d/
		                   providing pluggable build components (scripts)

		--files-dir        alternate directory for /lib/rock_initramfs/files/
		                   providing a location for files needed by
		                   build.d-scripts

		--root-dir         prefix for some directory locations
		                   (/lib/modules, /lib/rock_initramfs
		                    and --files-dir, --build-dir if relative)
		
		--gen_init_cpio    alternate binary for gen_init_cpio
		                   (usefull when default binary was cross compiled)

		--add-gen-line     additional line to be passed to gen_init_cpio
		                   (usefull for small changes without modifying
						    the whole build.d/-directory)

	EOF
}

rootdir=""

while [ ${#} -gt 0 ]
do
	case "$1" in
		-v)	verbose=yes
			;;
		-r)
			k_ver=$2
			shift
			;;
		-m)
			mod_origin=$2
			shift
			;;
		-O)
			listoutfile=$2
			shift
			;;
		-o)
			outfile=$2
			shift
			;;
		-p)
			scriptopt="$scriptopt ${2%%=*}='${2#*=}'"
			shift
			;;
		--root-dir)
			rootdir="$2"
			shift
			;;
		--build-dir)
			builddir="$2"
			shift
			;;
		--files-dir)
			filesdir="$2"
			shift
			;;
		--libexec-dir)
			libexecdir="$2"
			shift
			;;
		--add-gen-line)
			additional_gen_lines="$additional_gen_lines;$2"
			shift
			;;
		--gen_init_cpio)
			gen_init_cpio="$2"
			shift
			;;
		*)
			usage=1
			;;
	esac
	shift
done

[ -n "${rootdir}" -a "${rootdir:0:1}" != "/" ] && rootdir="`pwd`/$rootdir"

[ -z "$mod_origin" ] && mod_origin=$rootdir/lib/modules/$k_ver
[ -z "$outfile" ] && outfile=$rootdir/boot/initramfs-$k_ver.cpio.gz
[ -z "$listoutfile" ] && listoutfile=$rootdir/boot/initramfs-$k_ver.cpio.lst

if [ "$usage" = "1" ]
then
	usage
	exit
fi

export BASE=$rootdir/lib/rock_initramfs

[ -z "$builddir" ]   && builddir="$BASE/build.d"
[ -z "$filesdir" ]   && filesdir="$BASE/files"
[ -z "$libexecdir" ] && libexecdir="$BASE/libexec"
[ "${builddir:0:1}" = "/" ]   || builddir="$rootdir/$builddir"
[ "${filesdir:0:1}" = "/" ]   || filesdir="$rootdir/$filesdir"
[ "${libexecdir:0:1}" = "/" ] || libexecdir="$rootdir/$libexecdir"

[ ${outfile:0:1} = "/" ] || outfile="`pwd`/$outfile"
[ ${listoutfile:0:1} = "/" ] || listoutfile="`pwd`/$listoutfile"
[ ${mod_origin:0:1} = "/" ] || mod_origin="`pwd`/$mod_origin"

[ -z "$rootdir" ] && rootdir=/

cat << EOF
kernel version: $k_ver
module origin: $mod_origin
output file: $outfile

root dir: $rootdir
build dir: $builddir
files dir: $filesdir
libexec dir: $libexecdir
EOF

export rootdir
export builddir
export filesdir
export verbose

export k_ver mod_origin scriptopt

# provide a tmpdir to our helpers
export TMPDIR="/tmp/irfs-`date +%s`.$$"
mkdir -pv $TMPDIR

# compile our list of cpio-content
. ${libexecdir}/functions
${libexecdir}/build-list.sh > ${TMPDIR}/list
echo "$additional_gen_lines" | tr ';' '\n' >> ${TMPDIR}/list

if [ -n "$verbose" ]
then
	echo "compiled list:"
	echo "======================="
	cat ${TMPDIR}/list
	echo "======================="
fi

# create and compress cpio archive
if [ -z "$gen_init_cpio" ] ; then
	${libexecdir}/gen_init_cpio ${TMPDIR}/list | gzip -9 > $outfile
else
	${gen_init_cpio} ${TMPDIR}/list | gzip -9 > $outfile
fi

[ -n "$listoutfile" ] && cp -v ${TMPDIR}/list "$listoutfile"

if [ -n "$verbose" ]
then
	echo "contents of TMPDIR=$TMPDIR:"
	echo "======================="
	find $TMPDIR
	echo "======================="
fi
# remove the tmpdir
rm -rf $TMPDIR

# can be extracted with:
# gzip -dc ../irfs.cpio.gz | ( rm -rf ./root ; mkdir root ; cd root ; cpio -i -d -H newc --no-absolute-filenames )
