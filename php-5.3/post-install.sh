v=5.3
for tool in pear peardev pecl php phar phar.phar php-cgi php-config phpize; do
  if [ -e ~/php/5.3.29/bin/"$tool" ]; then
    sudo cp ~/php/5.3.29/bin/"$tool" /usr/bin/"$tool$v"
    sudo update-alternatives --install /usr/bin/"$tool" "$tool" /usr/bin/"$tool$v" 50
    sudo update-alternatives --set $tool /usr/bin/"$tool$v"
  fi
done
ini_file=$(php -d "date.timezone=UTC" --ini | grep "Loaded Configuration" | sed -e "s|.*:s*||" | sed "s/ //g")
sudo chmod 777 "$ini_file"
echo -e "date.timezone=UTC\nmemory_limit=-1" >>"$ini_file"