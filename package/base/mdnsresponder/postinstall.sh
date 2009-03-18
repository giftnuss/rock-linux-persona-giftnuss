#!/bin/sh

if any_installed "lib/libnss_mdns.so.2" ; then
	echo "mdnsresponder: adding 'mdns' to host: line in /etc/nsswitch.conf .."
	sed -i -e '/mdns/! s/^\(hosts:.*\)dns\(.*\)/\1mdns dns\2/' /etc/nsswitch.conf
fi

if any_removed "lib/libnss_mdns.so.2" ; then
	echo "mdnsresponder: removing 'mdns' from host: line in /etc/nsswitch.conf .."
	sed -i -e 's/^\(hosts:.*\)mdns \(.*\)/\1\2/' /etc/nsswitch.conf
fi
