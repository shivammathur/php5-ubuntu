#!/bin/bash -eu

cp -a php-build/definitions/* /usr/local/share/php-build/definitions/
cp -a php-build/patches/*.patch /usr/local/share/php-build/patches/
cp /usr/local/share/php-build/definitions/default /usr/local/share/php-build/default_configure_options
cp /usr/local/share/php-build/default_configure_options /usr/local/share/php-build/default_configure_options.bak

# Patch to enable opcache in opcache.ini instead of php.ini
sed -i -e "s|opcache.so\" >> \"\$PREFIX/etc/php.ini|opcache.so\" >> \"\$PREFIX/etc/conf.d/10-opcache.ini|" \
       -e "s|./configure \$argv|echo \$argv\\n    ./configure \$argv|" "$(command -v php-build)"