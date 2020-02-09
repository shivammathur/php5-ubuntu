apt_install="sudo DEBIAN_FRONTEND=noninteractive apt-get install -o Dpkg::Options::=--force-conflicts -y --allow-downgrades --no-upgrade"
dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts"
sudo mkdir -p /var/run /run/php
$dpkg_install ./deps/*.deb
$apt_install libcurl3
$dpkg_install ./*.deb
for tool in php5 php5-cgi php-config5 phpize5; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/5/}
    sudo cp /usr/bin/"$tool" /usr/bin/"$tool_name"5.3
    sudo update-alternatives --install /usr/bin/"$tool_name" "$tool_name" /usr/bin/"$tool_name"5.3 50
  fi
done