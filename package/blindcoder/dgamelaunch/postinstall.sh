#!/bin/bash

if any_installed "dgamelaunch_telnetd" ; then
	echo "Adding dgamelaunch to /etc/inetd.conf"
	grep -q dgamelaunch /etc/inetd.conf || cat >>/etc/inetd.conf<<EOF
#telnet stream tcp nowait root.root /usr/sbin/tcpd /usr/sbin/in.telnetd -h -L /usr/sbin/dgamelaunch_telnetd
EOF
fi

if any_removed "dgamelaunch_telnetd" ; then
	echo "Removing dgamelaunch from /etc/inetd.conf"
	cp /etc/inetd.conf{,.bak}
	tmp="`mktemp`"
	rm -f $tmp
	grep -v "dgamelaunch_telnetd" /etc/inetd.conf >$tmp
	cat $tmp > /etc/inetd.conf
fi
