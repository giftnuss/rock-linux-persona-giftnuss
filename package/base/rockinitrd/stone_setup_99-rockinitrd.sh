#!/bin/bash

for x in /lib/modules/* ; do
	mkinitrd ${x##*/}
done
