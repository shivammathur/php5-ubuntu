dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts"
sudo mkdir -p /var/run /run/php ~/php
$dpkg_install ./deps/*.deb
sudo tar xJf ./php-5.3.29.tar.xz -C ~/php
sudo ln -sf ~/php/5.3.29/etc/php.ini /etc/php.ini