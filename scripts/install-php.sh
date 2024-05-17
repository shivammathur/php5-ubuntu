. /etc/os-release
debconf_fix="DEBIAN_FRONTEND=noninteractive"
dpkg_install="sudo $debconf_fix dpkg -i --force-conflicts --force-overwrite"
sudo mkdir -p /var/run /run/php /usr/local/php /usr/lib/systemd/system /usr/lib/cgi-bin /var/www/html
[[ "$VERSION_ID" = "20.04" || "$VERSION_ID" = "22.04" || $VERSION_ID = "24.04" ]] && $dpkg_install ./deps/"$VERSION_ID"/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$VERSION_ID"/*.deb
$dpkg_install ./deps/all/*.deb
sudo tar -I zstd -xf ./php-@PHP_VERSION@-build.tar.zst -C /usr/local/php
sudo ln -sf /usr/local/php/@PHP_VERSION@/etc/php.ini /etc/php.ini
