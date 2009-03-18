#!/bin/bash

. /etc/profile
rm -f /etc/xml/catalog
xmlcatalog --noout --create /etc/xml/catalog
for catfile in `echo $XML_CATALOG_FILES | tr ' ' '\n' | sort -u`; do
	xmlcatalog --noout --add nextCatalog $catfile "" /etc/xml/catalog
done

