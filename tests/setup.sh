#!/bin/bash

set -e

__DIR__=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

cd $__DIR__

if [ -d assert.sh ] ; then
    (cd assert.sh ; git pull)
else
    git clone https://github.com/lehmannro/assert.sh.git
fi
