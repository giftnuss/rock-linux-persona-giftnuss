#!/bin/bash

pmfile=
for x in \
	/usr/lib/perl*/*/${1//::/\/}.pm \
	/usr/lib/perl*/*/*/${1//::/\/}.pm \
	/usr/lib/perl*/*/*/*/${1//::/\/}.pm
do
	if [ -z "$pmfile" -a -f $x ]; then
		pmfile="$x"
	fi
done

if [ -z "$pmfile" ]; then
	echo "No *.pm file for $1 found."
	exit
fi

get_pm_desc()
{
	gawk '
		BEGIN { state = 0; }
		$1 == "=head1" && state != 0 { state = 0; }
		$1 == "=head1" && $2 == "'"$1"'" { state = 1; next; }
		$1 != "" && state == 1 { state = 2; }
		$1 == "" && state == 2 { state = 0; }
		state == 2 { print; }
	' < $pmfile
}

{
	get_pm_desc NAME | perl -pe 's,^.*?- *,[I] ,' | head -n 1
	get_pm_desc DESCRIPTION | fmt | perl -pe 's,^,[T] ,'
	get_pm_desc AUTHORS | perl -pe 's,^,[A] ,'
} | perl -pe 's/<lt>/</ig; s/<gt>/>/ig;'

