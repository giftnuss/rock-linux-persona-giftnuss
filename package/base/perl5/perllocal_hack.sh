
# Quick & Dirty hack for the perllocal problem
# .. to be included by packages which do 'share' the perllocal.pod file
#
eval `perl -V:archlib`
for basename in \
	perllocal cpan
do
	hook_add premake 1 "( cd $archlib; mv -v $basename.pod $basename.pod.sik || true; )"
	hook_add postmake 9 "( cd $archlib; mv -v $basename.pod $pkg.pod || true;
			       mv -v $basename.pod.sik $basename.pod || true; )"
	var_append flist''del '|' "${archlib#/}/$basename.pod"
done

