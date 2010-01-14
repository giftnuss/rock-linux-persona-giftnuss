#!/bin/bash

URL=https://www.rocklinux.net/submaster/

if [ $# -lt 3 ]; then
	echo
	echo "Usage: $0 { username password | - } file(s)"
	echo
	echo
	echo "Usage example:"
	echo
	echo "   git-format-patch HEAD~4"
	echo "   $0 username password 000[1-4]-*.patch"
	echo
	exit 1
fi

username="$1"; shift
if [ "$username" != "-" ]; then
	password="$1"; shift
fi

i=0
for p; do
	fn=`printf "git-send-tmp%03d.txt" $i`
	awk 'pass { print; next; } /^From:/ { gsub(/^From: /, ""); gsub(/ *<.*/, ""); name=$0; next; } /^Subject:/ { gsub(/^.*PATCH[0-9/ ]*\] */, ""); message="\t" $0; next; } /^---/ { print "\n" name ":\n" message "\n"; next; } /^diff/ { print; pass=1; next; } /./ { message = message "\n\t" $0; }' < "$p" > $fn
	if [ "$username" != "-" ]; then
		curl -k -F u="$username" -F p="$password" -F a=new -F q=1 -F f=\@$fn "$URL/smadm.cgi"
	fi
	i=`expr $i + 1`
done

