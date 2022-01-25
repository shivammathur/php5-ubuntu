#!/bin/bash -eu

[ ! -d ~/php-build ] || return 0

git clone -b php5 https://github.com/shivammathur/php-build ~/php-build
cd ~/php-build && sudo ./install.sh