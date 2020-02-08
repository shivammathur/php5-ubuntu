v=5.5
for tool in php$v php-cgi$v php-config$v phpize$v; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/[0-9]*/}
    sudo update-alternatives --set $tool_name /usr/bin/"$tool_name$v"
  fi
done
ini_file=$(php -d "date.timezone=UTC" --ini | grep "Loaded Configuration" | sed -e "s|.*:s*||" | sed "s/ //g")
sudo chmod 777 "$ini_file"
echo "date.timezone=UTC" >>"$ini_file"
sudo php5enmod redis
sudo php5enmod xdebug