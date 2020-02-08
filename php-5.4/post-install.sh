v=5.4
for tool in php$v php-cgi$v php-config$v phpize$v; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/[0-9]*/}
    sudo update-alternatives --set $tool_name /usr/bin/"$tool_name$v"
  fi
done
sudo php5enmod redis
sudo php5enmod xdebug