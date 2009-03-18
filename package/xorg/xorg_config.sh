
prefix="usr/X11R7"
set_confopt

if [[ "$xpkg" == font-* && "$xpkg" != font-util ]] ; then
	xorg_fonts_preconf ()
	{
		# This prevents creation of fonts.scale and font.dir files.
		sed -i -e's,\(.*$(MAKE).*install-data-hook\),#\1,' Makefile.in
	}
	hook_add preconf 5 xorg_fonts_preconf
fi

createdocs=0
forcefpic=0

var_remove GCC3_WRAPPER_INSERT " " "-fstack-protector"

# documentation files
splitreg 50 doc 'usr/X11.*/lib/X11/doc'

# this fixes many cyclic dependencies..
var_append flistrfilter "|" ".*mkhtmlindex.pl.*X11/doc/html.*"

SUDO=""
DESTDIR="$root/"
PREFIX="$prefix"

# Must create local aclocal dir or aclocal fails
ACLOCAL_LOCALDIR="${DESTDIR}${PREFIX}/share/aclocal"
$SUDO mkdir -p ${ACLOCAL_LOCALDIR}

# The following is required to make aclocal find our .m4 macros
if test x"$ACLOCAL" = x; then
    ACLOCAL="aclocal -I ${ACLOCAL_LOCALDIR}"
else
    ACLOCAL="${ACLOCAL} -I ${ACLOCAL_LOCALDIR}"
fi
export ACLOCAL

# The following is required to make pkg-config find our .pc metadata files
if test x"$PKG_CONFIG_PATH" = x; then
    PKG_CONFIG_PATH=${DESTDIR}${PREFIX}/lib/pkgconfig
else
    PKG_CONFIG_PATH=${DESTDIR}${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
fi
export PKG_CONFIG_PATH

# Set the library path so that locally built libs will be found by apps
if test x"$LD_LIBRARY_PATH" = x; then
    LD_LIBRARY_PATH=${DESTDIR}${PREFIX}/lib
else
    LD_LIBRARY_PATH=${DESTDIR}${PREFIX}/lib:${LD_LIBRARY_PATH}
fi
export LD_LIBRARY_PATH

# Set the path so that locally built apps will be found and used
if test x"$PATH" = x; then
    PATH=${DESTDIR}${PREFIX}/bin
else
    PATH=${DESTDIR}${PREFIX}/bin:${PATH}
fi
export PATH

# Set the default font path for xserver/xorg unless it's already set
if test x"$FONTPATH" = x; then
    FONTPATH="${PREFIX}/lib/X11/fonts/misc/,${PREFIX}/lib/X11/fonts/Type1/,${PREFIX}/lib/X11/fonts/75dpi/,${PREFIX}/lib/X11/fonts/100dpi/,${PREFIX}/lib/X11/fonts/cyrillic/,${PREFIX}/lib/X11/fonts/TTF/"
    export FONTPATH
fi
