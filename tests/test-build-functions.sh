#!/bin/bash

set -e

source tests/assert.sh/assert.sh
source scripts/functions
source scripts/build-functions

# helpers
set_builddir () {
    builddir=$(mktemp -d -p .)
}
clean_builddir () {
    rm -rf $builddir
}

### -------------------------

exec 202>&1
base=.
download=0
desc_D="467800010 dash-0.5.10.tar.gz http://gondor.apana.org.au/~herbert/dash/files/"

set_builddir
build_setup_archdir >/dev/null
assert "echo $archdir" "$builddir/archdir"
assert "ls $archdir" dash-0.5.10.tar.bz2
clean_builddir
assert_end build_setup_archdir

### -------------------------

xsourceballs=""
srctar=auto
desc_D="467800010 dash-0.5.10.tar.gz http://gondor.apana.org.au/~herbert/dash/files/"

assert "build_set_sourceballs"
build_set_sourceballs

assert "echo $xsourceballs" dash-0.5.10.tar.bz2
assert_end build_set_sourceballs



assert_end build_autoextract_source
