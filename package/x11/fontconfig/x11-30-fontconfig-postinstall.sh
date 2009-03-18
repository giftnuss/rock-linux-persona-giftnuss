#!/bin/sh

if [ "`which fc-cache`" ] ; then
	echo "Running fc-cache ..."
	fc-cache -v
fi
