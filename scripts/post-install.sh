v=@PHP_VERSION@
prefix=/usr/local/php/"$v"
api_suffix="$(find "$prefix"/lib/php/extensions -type d -regextype posix-egrep -regex ".*[0-9]{8}" | rev | cut -d'-' -f 1 | rev)"
sudo rm -rf /usr/bin/pecl /usr/bin/pear* 2>/dev/null || true
sudo cp -fp switch_sapi php-fpm-socket-helper "$prefix"/bin/
sudo cp -a "$prefix"/usr/lib/* /usr/lib/
for tool in pear peardev pecl php phar phar.phar php-cgi php-fpm php-config phpize switch_sapi; do
  if [ -e "$prefix"/bin/"$tool" ]; then
    sudo cp -fp "$prefix"/bin/"$tool" /usr/bin/"$tool$v"
    sudo update-alternatives --install /usr/bin/"$tool" "$tool" /usr/bin/"$tool$v" "${v/./}"
    sudo update-alternatives --set "$tool" /usr/bin/"$tool$v"
  fi
done
sudo update-alternatives --install /usr/lib/cgi-bin/php php-cgi-bin /usr/lib/cgi-bin/php"$v" "${v/./}"
sudo update-alternatives --install /usr/lib/libphp5.so libphp5 "$prefix"/usr/lib/libphp"$v".so "${v/./}" && sudo ldconfig
sudo update-alternatives --set php-cgi-bin /usr/lib/cgi-bin/php"$v"
sudo ln -sf "$prefix"/include/php /usr/include/php/"$api_suffix"
ini_file=$(php --ini | grep "Loaded Configuration" | sed -e "s|.*:s*||" | sed "s/ //g")
sudo chmod 777 "$ini_file" /usr/bin/switch_sapi "$prefix"/bin/php-fpm-socket-helper
echo -e "\ndate.timezone=UTC\nmemory_limit=-1" >>"$ini_file"
sudo cp -fp ./conf/*.conf /etc/apache2/mods-available/
sudo cp -fp ./conf/default_apache /etc/apache2/sites-available/default
sudo cp -fp "$prefix"/etc/apache2/mods-available/* /etc/apache2/mods-available/
sudo cp -fp "$prefix"/etc/init.d/php"$v"-fpm /etc/init.d/php"$v"-fpm
sudo cp -fp "$prefix"/etc/systemd/system/php"$v"-fpm.service /lib/systemd/system/
sudo chmod a+x "$prefix"/bin/php-fpm-socket-helper
sudo a2enmod php"$v"
sudo service php"$v"-fpm start
sudo service apache2 stop
