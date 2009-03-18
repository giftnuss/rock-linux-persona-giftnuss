if [ "$install_checks_true" = 1 ] ; then
	gconftool-2 --install-schema-file D_sysconfdir/gconf/schemas/*
else
	dir="D_sysconfdir"; dir=${dir#/}
	all_touched "$dir/gconf/schemas/.*\.schemas" |
	while read x ; do
		gconftool-2 --install-schema-file "/$x"
	done
	unset dir x
fi
