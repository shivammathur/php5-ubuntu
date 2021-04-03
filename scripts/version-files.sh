#!/bin/bash -eu

PHP_VERSION=$1
grep -lr "@PHP_VERSION@" scripts | xargs sed -i "s/@PHP_VERSION@/$PHP_VERSION/g"
grep -lr "@PHP_VERSION@" conf | xargs sed -i "s/@PHP_VERSION@/$PHP_VERSION/g"
sed -i "s/@NOT_DOT@/${PHP_VERSION/./}/g" conf/php-fpm.service
mv conf/php-fpm.service conf/php"$PHP_VERSION"-fpm.service
mv conf/php-cgi.conf conf/php"$PHP_VERSION"-cgi.conf
mv conf/php-fpm.conf conf/php"$PHP_VERSION"-fpm.conf
mv conf/php.conf conf/php"$PHP_VERSION".conf
mv conf/php.load conf/php"$PHP_VERSION".load
