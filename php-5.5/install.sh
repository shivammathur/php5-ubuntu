dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts"
sudo mkdir -p /var/run /run/php /usr/lib/php5
. /etc/os-release
$dpkg_install ./deps/"$VERSION_ID"/*.deb
$dpkg_install ./deps/all/*.deb
$dpkg_install ./*.deb
sudo tar -x -k -f ./php5-fpm_5.5.38-1_dotdeb+7.1_amd64.gz -C /
sudo cp /etc/init.d/php5-fpm /etc/init.d/php5.5-fpm
for tool in php5 php5-cgi php5-fpm php-config5 phpize5; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/5/}
    sudo cp /usr/bin/"$tool" /usr/bin/"$tool_name"5.5
    sudo update-alternatives --install /usr/bin/"$tool_name" "$tool_name" /usr/bin/"$tool_name"5.5 50
  fi
done