#!/bin/bash

touch .gitignore
sort -u .gitignore - > .gitignore.new << EOT
build
config
download
smap.cfg
src.*
src
EOT
mv .gitignore.new .gitignore

git-init
git-add Documentation architecture misc package scripts target .gitignore
git-commit -m 'Init'

