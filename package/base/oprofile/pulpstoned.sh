#!/bin/bash
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/oprofile/pulpstoned.sh
# ROCK Linux is Copyright (C) 1998 - 2006 Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ROCK-COPYRIGHT-NOTE-END ---

period=600
report_script=pulpstoner
report_dir=/var/log/pulpstone
pidfile=/var/run/pulpstoned.pid

cd /; mkdir -p $report_dir
echo "pulpstone daemon: writing logs to $report_dir ..."

(

psd_end() {
	opcontrol -h
	echo "Shutting down on signal."
	rm -f $pidfile
	date +"=== <%Y/%m/%d %H:%M:%S> ==="
	exit 0
}

trap psd_end INT TERM
echo $$ > $pidfile

while true; do
	now=`date +"%Y%m%d%H"`
	exec >> $report_dir/$now.log 2>&1
	for x in $report_dir/*.log; do
		[ "$x" = "$report_dir/$now.log" ] && continue
		echo; echo "Uploading $report_dir/$now.log ..."
		res="$( curl -s -F data=@$x http://www.rocklinux.net/pulpstone/upload.cgi )"
		if [ "$res" = "ok" ]; then
			echo "File upload succesfull."
			mv $x ${x%.log}.old
		else
			echo "Error while uploading."
		fi
	done
	date +"%n=== <%Y/%m/%d %H:%M:%S> ==="
	opcontrol -s
	opcontrol --reset
	opcontrol --event="CPU_CLK_UNHALTED:100000:0:1:1"
	for ((c=0; c<period; c++)); do sleep 1; done
	opcontrol -h
	date +"=== <%Y/%m/%d %H:%M:%S> ==="
	nice -n 99 $report_script | unexpand -a
	date +"=== <%Y/%m/%d %H:%M:%S> ==="
done

) &

