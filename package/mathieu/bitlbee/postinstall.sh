#!/bin/bash

if any_installed "bitlbee" ; then
	echo "Adding bitlbee to /etc/inetd.conf"
	grep -q bitlbee /etc/inetd.conf || cat >>/etc/inetd.conf<<EOF
#6667 stream tcp nowait bitlbee.bitlbee /usr/sbin/tcpd /usr/sbin/bitlbee # added by ROCK
EOF
fi

if any_removed "bitlbee" ; then
	echo "Removing bitlbee from /etc/inetd.conf"
	cp /etc/inetd.conf{,.bak.bitlbee.$(date +%Y%m%d%H%M%S)}
	tmp="`mktemp`"
	rm -f ${tmp}
	touch ${tmp}
	chmod 600 ${tmp}
	grep -v "bitlbee.*# added by ROCK" /etc/inetd.conf >${tmp}
	cat ${tmp} > /etc/inetd.conf
	rm -f ${tmp}
fi
