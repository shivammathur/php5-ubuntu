#!/bin/bash -eu

[ ! -d ~/php-build ] || return 0

git clone git://github.com/php-build/php-build ~/php-build
cd ~/php-build && sudo ./install.sh
