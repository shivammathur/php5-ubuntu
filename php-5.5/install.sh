dpkg_install="sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts"
sudo mkdir -p /var/run /run/php
[ "$(lsb_release -r -s)" = "20.04" ] && $dpkg_install ./deps/20.04/multiarch-support_2.28-10_amd64
$dpkg_install ./deps/"$(lsb_release -r -s)"/*.deb
$dpkg_install ./deps/all/*.deb
$dpkg_install ./*.deb
for tool in php5 php5-cgi php-config5 phpize5; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/5/}
    sudo cp /usr/bin/"$tool" /usr/bin/"$tool_name"5.5
    sudo update-alternatives --install /usr/bin/"$tool_name" "$tool_name" /usr/bin/"$tool_name"5.5 50
  fi
done