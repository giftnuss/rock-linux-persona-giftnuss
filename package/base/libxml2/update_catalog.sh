#!/bin/bash

. /etc/profile
rm -f $root/etc/xml/catalog
xmlcatalog --noout --create $root/etc/xml/catalog
for catfile in `echo $XML_CATALOG_FILES | tr ' ' '\n' | sort -u`; do
	xmlcatalog --noout --add nextCatalog $catfile "" $root/etc/xml/catalog
done

