v=5.5
dotdeb=http://packages.dotdeb.org
for tool in php$v php-cgi$v php-config$v phpize$v; do
  if [ -f /usr/bin/"$tool" ]; then
    tool_name=${tool/[0-9]*/}
    sudo update-alternatives --set $tool_name /usr/bin/"$tool_name$v"
  fi
done
ini_file=$(php -d "date.timezone=UTC" --ini | grep "Loaded Configuration" | sed -e "s|.*:s*||" | sed "s/ //g")
sudo chmod 777 "$ini_file"
echo "date.timezone=UTC" >>"$ini_file"
sudo mv ./deps/libcurl.so.3 /usr/lib/libcurl.so.3
sudo mv ./deps/curl.so "$(php -i | grep "extension_dir => /usr" | sed -e "s|.*=> s*||")"/curl.so
echo "extension=curl.so" >>"$ini_file"
sudo php5enmod redis
sudo php5enmod xdebug
echo "deb $dotdeb wheezy-php55 all" | sudo tee /etc/apt/sources.list.d/dotdeb-ubuntu-php-"$(lsb_release -s -c)".list
curl -sSLO https://www.dotdeb.org/dotdeb.gpg
sudo apt-key add dotdeb.gpg