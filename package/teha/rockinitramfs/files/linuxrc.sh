#!/bin/sh
. /etc/profile
for x in /init.d/*
do
	. $x
done

echo "end of build.d reached -- spawning /bin/bash..."
exec /bin/bash --login
