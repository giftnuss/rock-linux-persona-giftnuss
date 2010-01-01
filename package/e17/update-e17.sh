#!/bin/sh

# TODO:
#    * list revisions only - no change mode
#    * change only lines with [V] and [D]

OLD=$1
NEW=$2

if [ ".$OLD" == ".list" ] ; then
  for i in package/e17/*/*.desc ; do
    echo  $(grep "\[V\] r" $i) $(basename $i .desc)
  done
  exit
fi

if [ -z "$NEW" ] ; then
  echo "run as: $0 oldrevision newrevision"
  exit 1
fi

echo "Updating packages in the e17 repository from revision $OLD to $NEW"

for pkg in $(grep -l "\[V\] r$OLD" package/e17/*/*.desc); do
  echo "Updating $pkg"
  sed -i -e"s/$OLD/$NEW/g" $pkg
done

echo "Update done."
