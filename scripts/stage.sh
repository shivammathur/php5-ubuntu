#!/bin/bash -eu

PHP_VERSION=$1
mkdir -p php-"$PHP_VERSION" php-"$PHP_VERSION"/conf php-"$PHP_VERSION"/deps
for script in install-php.sh post-install.sh php-fpm-socket-helper switch_sapi; do
  cp scripts/"$script" php-"$PHP_VERSION"/
done
cp -rf conf/* php-"$PHP_VERSION"/conf
cp -rf deps/* php-"$PHP_VERSION"/deps
cp -rf php-"$PHP_VERSION" /tmp/php-"$PHP_VERSION"
