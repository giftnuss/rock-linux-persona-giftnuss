#!/bin/bash

URL=https://www.rocklinux.net/submaster/

if [ $# -lt 3 ]; then
	echo
	echo "Usage example:"
	echo
	echo "   git-format-patch HEAD~4"
	echo "   $0 username password 000[1-4]-*.patch"
	echo
	exit 1
fi

username="$1"; shift
password="$1"; shift

for p; do
	awk 'pass { print; next; } /^From:/ { gsub(/^From: /, ""); gsub(/<.*/, ""); name=$0; next; } /^Subject:/ { gsub(/^.*PATCH\] */, ""); message="\t" $0; next; } /^---/ { print "\n" name ":\n" message "\n"; next; } /^diff/ { print; pass=1; next; } /./ { message = message "\n\t" $0; }' < "$p" > git-send-tmp.txt
	curl -k -F u="$username" -F p="$password" -F a=new -F q=1 -F f=\@git-send-tmp.txt "$URL/smadm.cgi"
done

