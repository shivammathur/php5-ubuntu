#!/usr/bin/env bash
# PHP expressions below intentionally use literal dollar signs.
# shellcheck disable=SC2016
set -euo pipefail
umask 022
here=$(cd "$(dirname "$0")" && pwd)
command -v zstd >/dev/null || sudo apt-get install -y zstd
suffix='';[[ "$EXPECTED_ARCHITECTURE" = arm64 ]] && suffix=-arm64
cd "$PRIVATE_TASK_DIR"
tar -I zstd -xf "$PACKAGE_DIR/php-$PHP_VERSION$suffix.tar.zst"
mkdir "$PRIVATE_TASK_DIR/raw"
tar -I zstd -xf "$PACKAGE_DIR/php-$PHP_VERSION-build$suffix.tar.zst" -C "$PRIVATE_TASK_DIR/raw"
python3 "$here/check-runtime.py" "$PRIVATE_TASK_DIR/raw/$PHP_VERSION" "$EXPECTED_ARCHITECTURE" > "$REPORT_DIR/runtime-inspection.json"
cd "php-$PHP_VERSION"
chmod a+x ./*.sh
./install-php.sh
./post-install.sh
sudo apt-get check
test -z "$(dpkg --audit)"
phpbin="/usr/local/php/$PHP_VERSION/bin/php"
actual=$("$phpbin" -r 'echo PHP_VERSION;')
[[ "$actual" = "$PHP_FULL_VERSION" ]]
"$phpbin" --ini
"$phpbin" -v > "$REPORT_DIR/php-version.txt" 2>&1
"$phpbin" -m > "$REPORT_DIR/php-modules.txt" 2>&1
cat "$REPORT_DIR/php-version.txt" "$REPORT_DIR/php-modules.txt"
if grep -Ei '(^PHP (Warning|Fatal|Notice|Deprecated)|PHP Startup:)' "$REPORT_DIR/php-version.txt" "$REPORT_DIR/php-modules.txt"; then exit 1; fi
php-config --version
phpize --version
php-cgi -v
php-fpm -v
pecl -V
sudo service "php$PHP_VERSION-fpm" status
"$phpbin" "$here/smoke.php"
# Exercise all server SAPIs through the same installed switch helper.
sudo rm -f /var/www/html/index.html
printf '%s\n' '<?php echo current(explode("-", php_sapi_name())).":".strtolower(current(explode("/", $_SERVER["SERVER_SOFTWARE"])))."\n";' | sudo tee /var/www/html/index.php >/dev/null
for sapi in apache2handler:apache fpm:apache cgi:apache fpm:nginx; do
  sudo switch_sapi "$sapi" >/dev/null
  actual=$(curl -fsS --retry 3 http://localhost)
  [[ "$actual" = "$sapi" ]]
  printf '%s\n' "$actual"
done
