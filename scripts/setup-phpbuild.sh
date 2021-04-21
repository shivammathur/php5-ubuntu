#!/bin/bash -eu

cp -a php-build/definitions/* /usr/local/share/php-build/definitions/
cp -a php-build/patches/*.patch /usr/local/share/php-build/patches/
cp /usr/local/share/php-build/default_configure_options /usr/local/share/php-build/default_configure_options.bak

# Patch to enable opcache in opcache.ini instead of php.ini
sed -i "s|opcache.so\" >> \"\$PREFIX/etc/php.ini|opcache.so\" >> \"\$PREFIX/etc/conf.d/opcache.ini|" "$(command -v php-build)"