debconf_fix="DEBIAN_FRONTEND=noninteractive"
dpkg_install="sudo $debconf_fix dpkg -i --force-conflicts --force-overwrite"
if command -v apache2 && [ "2.2" != "$(apache2 -v 2>/dev/null | grep -Eo "([0-9]+\.[0-9]+)")" ]; then
  sudo "$debconf_fix" apt-get purge apache2-data apache2-bin apache2 apache2-utils
  sudo rm -rf /etc/apache2 /var/lib/apache2 /var/lib/apache2 /usr/lib/apache2/modules/* /usr/share/apache2/*
fi
sudo mkdir -p /var/run /run/php /usr/local/php /usr/lib/systemd/system /usr/lib/cgi-bin /var/www/html
[ "$(lsb_release -r -s)" = "20.04" ] && $dpkg_install ./deps/20.04/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$(lsb_release -r -s)"/*.deb
$dpkg_install ./deps/all/*.deb
sudo tar -I zstd -xf ./php-5.3.tar.zst -C /usr/local/php
sudo ln -sf /usr/local/php/5.3/etc/php.ini /etc/php.ini
