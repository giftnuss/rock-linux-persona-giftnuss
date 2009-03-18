prefix="opt/nx-X11"
etcprefix="$prefix/etc"

# extract and patch base
xf_extract() {
	echo "Extracting source (for package version $ver) ..."
	for x in $archdir/* ; do
		tar $taropt $archdir/$x
	done

	cd nx-X11
}

# build the World
xf_build() {
	eval $MAKE World
	# cd nls ; eval $MAKE ; cd ..
}

# install the World
xf_install() {
	mkdir -p $root/$etcprefix

	if [ "$arch_sizeof_char_p" = 8 ] ; then
		mkdir -p $root/$prefix/X11R6/lib
		ln -s lib $root/$prefix/X11R6/lib64
	fi

	eval $MAKE install
	eval $MAKE install.man
	cd nls ; eval $MAKE install ; cd ..
	rm -fv $root/etc/fonts/*.bak

	rm -fv $root/$prefix/X11
	rm -fv $root/$prefix/bin/X11
	rm -fv $root/$prefix/lib/X11
	rm -fv $root/$prefix/include/X11

	ln -sv X11R6 $root/$prefix/X11
	ln -sv ../X11/bin $root/$prefix/bin/X11
	ln -sv ../X11/lib/X11 $root/$prefix/lib/X11
	ln -sv ../X11/include/X11 $root/$prefix/include/X11

	mkdir -p $root/$prefix/X11R6/lib/X11/fonts/TrueType
	
	echo "Copy TWM config files ..."
	cp -v programs/twm/system.twmrc.orig \
	  programs/twm/sample-twmrc/original.twmrc
	cp -v programs/twm/sample-twmrc/*.twmrc $root/usr/X11R6/lib/X11/twm/
	register_wm twm TWM /usr/X11/bin/twm

	echo "Copying default example configs ..."
	        cp -fv $base/package/x11/${pkg}/xorg.conf.data \
			$root/$etcprefix/X11/xorg.conf.example
		cp -fv $root/$etcprefix/X11/xorg.conf{.example,}
		cp -fv $base/package/x11/${pkg}/local.conf.data \
			$root/$etcprefix/fonts/local.conf

	echo "Fixing compiled keymaps directory ..."
	mkdir -p $root/var/lib/xkb $root/$etcprefix/X11/xkb
	cp -fu programs/xkbcomp/compiled/README $root/$prefix/var/lib/xkb
	rm -rf $root/$etcprefix/X11/xkb/compiled
	ln -sf $root/$prefix/var/lib/xkb $root/$etcprefix/X11/xkb/compiled
}

# configure the World
xf_config() {
	echo "Configuring X-Windows ..."
	cat >> config/cf/host.def << EOT
/* Disable the internal zlib to use the system installed one */
#define		HasZlib			YES
/* Disable the internal expat library to use the system installed one */
#define		HasExpat		YES

/* Less warnings with recent gccs ... */
#define		DefaultCCOptions	-ansi GccWarningOptions

/* Make sure config files are allways installed ... */
#define		InstallXinitConfig	YES
#define		InstallXdmConfig	YES
#define		InstallFSConfig		YES

/* do not install duplicate crap in /etc/X11 */
#define		UseSeparateConfDir	NO

EOT
}

