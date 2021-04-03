debconf_fix="DEBIAN_FRONTEND=noninteractive"
dpkg_install="sudo $debconf_fix dpkg -i --force-conflicts --force-overwrite"
sudo mkdir -p /var/run /run/php /usr/local/php /usr/lib/systemd/system /usr/lib/cgi-bin /var/www/html
[ "$(lsb_release -r -s)" = "20.04" ] && $dpkg_install ./deps/20.04/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$(lsb_release -r -s)"/*.deb
$dpkg_install ./deps/all/*.deb
sudo tar -I zstd -xf ./php-@PHP_VERSION@-build.tar.zst -C /usr/local/php
sudo ln -sf /usr/local/php/@PHP_VERSION@/etc/php.ini /etc/php.ini