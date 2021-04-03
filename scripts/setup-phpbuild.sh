#!/bin/bash -eu

cp -a php-build/definitions/* /usr/local/share/php-build/definitions/
cp -a php-build/patches/*.patch /usr/local/share/php-build/patches/
cp /usr/local/share/php-build/default_configure_options /usr/local/share/php-build/default_configure_options.bak
