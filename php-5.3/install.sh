dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts --force-overwrite"
sudo mkdir -p /var/run /run/php /usr/local/php
[ "$(lsb_release -r -s)" = "20.04" ] && $dpkg_install ./deps/20.04/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$(lsb_release -r -s)"/*.deb
$dpkg_install ./deps/all/*.deb
sudo tar -I zstd -xf ./php-5.3.tar.zst -C /usr/local/php
sudo ln -sf /usr/local/php/5.3/etc/php.ini /etc/php.ini
