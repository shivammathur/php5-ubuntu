debconf_fix="DEBIAN_FRONTEND=noninteractive"
dpkg_install="sudo $debconf_fix dpkg -i --force-conflicts --force-conflicts"
if command -v apache2 && [ "2.2" != "$(apache2 -v 2>/dev/null | grep -Eo "([0-9]+\.[0-9]+)")" ]; then
  sudo "$debconf_fix" apt-get purge apache2-data apache2-bin apache2 apache2-utils
  sudo rm -rf /etc/apache2 /var/lib/apache2 /var/lib/apache2 /usr/lib/apache2/modules/* /usr/share/apache2/*
fi
sudo mkdir -p /var/run /run/php /usr/lib/php5 /var/www/html
. /etc/os-release
$dpkg_install ./deps/"$VERSION_ID"/*.deb
$dpkg_install ./deps/all/*.deb
$dpkg_install ./*.deb
sudo tar -x -k -f ./php5-fpm_5.4.45-1_dotdeb+7.1_amd64.gz -C /
sudo cp -fp /etc/init.d/php5-fpm /etc/init.d/php5.4-fpm
sudo cp -fp switch_sapi /usr/bin/switch_sapi5
for tool in php5 php5-cgi php5-fpm php-config5 phpize5 switch_sapi5; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/5/}
    sudo cp -fp /usr/bin/"$tool" /usr/bin/"$tool_name"5.4
    sudo update-alternatives --install /usr/bin/"$tool_name" "$tool_name" /usr/bin/"$tool_name"5.4 50
  fi
done