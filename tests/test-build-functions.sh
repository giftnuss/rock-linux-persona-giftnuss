#!/bin/bash

set -e

source tests/assert.sh/assert.sh
source scripts/functions
source scripts/build-functions

# helpers
set_builddir () {
    builddir=$(mktemp -d -p $(pwd))
}
clean_builddir () {
    rm -rf $builddir
}

### -------------------------

exec 202>&1
base=$(pwd)
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

### -------------------------

exec 202>&1
base=$(pwd)
download=0
desc_D="467800010 dash-0.5.10.tar.gz http://gondor.apana.org.au/~herbert/dash/files/"
taropt="--use-compress-program=bzip2 -xf"
xsrctar=dash-0.5.10.tar.bz2
set_builddir
cd $builddir
build_setup_archdir >/dev/null

assert_raises '[ -d $archdir ]'
assert_raises '[ -L $archdir/$xsrctar ]'
build_autoextract_source
assert_raises '[ -s untar.txt ]'
assert_raises '[ -s xsrcdir.txt ]'
assert_raises '[ -d $builddir/dash-0.5.10 ]'

assert_end build_autoextract_source

srcdir=auto

build_set_xsrcdir
assert 'echo $xsrcdir' dash-0.5.10

assert_end build_set_xsrcdir
cd - >/dev/null
clean_builddir

### -------------------------

