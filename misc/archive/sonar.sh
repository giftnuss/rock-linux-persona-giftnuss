#!/bin/bash

usage() {
	cat <<EOF
$0: commit build results into ROCK Sonar

Usage:

$0 <config> [ <config> ... ]
EOF
	exit 1;
}

confirm() {
	unset yesno
	while [ "${yesno}" != "yes" -a "${yesno}" != "no" ] ; do
		echo -n "${@} [yes|no] ? "
		read yesno
	done
	[ "${yesno}" = "yes" ] && return 0
	return 1
}

commit(){
	. scripts/parse-config
	. config/${1}/config
	. config/${1}/config_usr

	if [ ! -d "build/${ROCKCFG_ID}/var/adm" ] ; then
		echo "Directory does not exist: build/${ROCKCFG_ID}/var/adm" >&2
		echo "Did you run Build-Target for this configuration?" >&2
		return 1
	fi

	echo "ROCK Version is: ${rockver}"
	revision="`svn info | grep Revision | cut -f2 -d' ' 2>&1`"
	echo "Subversion revision is: ${revision}"
	target="${ROCKCFG_TARGET}";
	echo "Target is: ${target}"
	echo "Please enter a description (for example: \"personal tree 2004-12-02\"):"
	read description
	echo "Please enter a comment: (for example: \"optimised for Pentium MMX\"):"
	read comment

	finished=0
	while [ ${finished} -eq 0 ] ; do
		echo "ROCK Version: ${rockver}"
		echo "Revision    : ${revision}"
		echo "Target      : ${target}"
		echo "Description : ${description}"
		echo "Comment     : ${comment}"

		if ! confirm "Do you want to change these information?" ; then
			finished=1
			continue
		fi

		read -p "ROCK Version [${rockver}]: " tmp
		[ -n "${tmp}" ] && rockver="${tmp}"
		unset tmp

		read -p "Revision [${revision}]: " tmp
		[ -n "${tmp}" ] && revision="${tmp}"
		unset tmp

		read -p "Target [${target}]: " tmp
		[ -n "${tmp}" ] && target="${tmp}"
		unset tmp

		read -p "Description [${description}]: " tmp
		[ -n "${tmp}" ] && description="${tmp}"
		unset tmp

		read -p "Comment [${comment}]: " tmp
		[ -n "${tmp}" ] && comment="${tmp}"
		unset tmp
	done

	echo -n "Creating varadm.tar.bz2 ... "
	cd build/${ROCKCFG_ID}/var/
	tar --use-compress-program=bzip2 -cf varadm.tar.bz2 adm/{dependencies,descs,flists}
	echo "done"
	echo -n "Uploading to ROCK Sonar ... "
	curl -k -F "v=${rockver}" -F "r=${revision}" -F "t=${target}" -F "d=${description}" -F "c=${comment}" -F "action=add" -F "f=@varadm.tar.bz2" http://sonar.rocklinux.org/
	echo "done"
	echo -n "Cleaning up ... "
	rm -f varadm.tar.bz2
	cd -
	echo "done"
}

[ -z "$1" ] && usage
while [ -n "${1}" ] ; do
	config="${1#config/}"

	if [ -d "config/${config}" ] ; then
		commit "${config}"
	else
		echo "Configuration \"${config}\" does not exist!" >&2
	fi
	
	shift
done
