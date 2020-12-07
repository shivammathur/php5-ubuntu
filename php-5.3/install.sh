dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts"
sudo mkdir -p /var/run /run/php ~/php
[ "$(lsb_release -r -s)" = "20.04" ] && $dpkg_install ./deps/20.04/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$(lsb_release -r -s)"/*.deb
$dpkg_install ./deps/all/*.deb
sudo tar -I zstd -xf ./php-5.3.29.tar.zst -C ~/php
sudo ln -sf ~/php/5.3.29/etc/php.ini /etc/php.ini
