setup_phpbuild() {
  (
    cd ~ || exit
    git clone git://github.com/php-build/php-build
    cd php-build || exit
    sudo ./install.sh
  )
  sudo cp .github/scripts/"$PHP_VERSION" /usr/local/share/php-build/definitions/
  if [ "$PHP_VERSION" = "5.3" ]; then
    sudo cp .github/scripts/php-5.3.29-multi-sapi.patch /usr/local/share/php-build/patches/
  fi
  cp /usr/local/share/php-build/default_configure_options /usr/local/share/php-build/default_configure_options.bak
}

setup_pear() {
  sudo rm -rf "$install_dir"/bin/pear "$install_dir"/bin/pecl
  sudo curl -fsSL --retry "$tries" -o /usr/local/ssl/cert.pem https://curl.haxx.se/ca/cacert.pem
  sudo curl -fsSL --retry "$tries" -O https://github.com/pear/pearweb_phars/raw/v1.9.7/go-pear.phar
  sudo chmod a+x .github/scripts/install-pear.expect
  .github/scripts/install-pear.expect "$install_dir"
  rm go-pear.phar
  sudo "$install_dir"/bin/pear config-set php_ini "$install_dir"/etc/php.ini system
  sudo "$install_dir"/bin/pear channel-update pear.php.net
}

build_embed() {
  cp /usr/local/share/php-build/default_configure_options.bak /usr/local/share/php-build/default_configure_options
  sudo sed -i "/apxs2/d" /usr/local/share/php-build/definitions/"$PHP_VERSION" || true
  sudo sed -i "/fpm/d" /usr/local/share/php-build/default_configure_options || true
  sudo sed -i "/cgi/d" /usr/local/share/php-build/default_configure_options || true
  echo "--enable-embed=shared" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  build_php
  mv "$install_dir" "$install_dir-embed"
}

configure_apache_fpm_opts() {
  sudo sed -i "/cgi/d" /usr/local/share/php-build/default_configure_options
  sudo sed -i '1iconfigure_option "--with-apxs2" "/usr/bin/apxs2"' /usr/local/share/php-build/definitions/"$PHP_VERSION"
  echo "--enable-cgi" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--enable-fpm" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--with-fpm-user=www-data" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--with-fpm-group=www-data" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
}

configure_apache_fpm() {
  sudo ln -sv "$install_dir"/sbin/php-fpm "$install_dir"/bin/php-fpm
  sudo ln -sv $install_dir/bin/php-cgi $install_dir/usr/lib/cgi-bin/php5.3
  sudo mkdir -p "$install_dir"/etc/systemd/system $install_dir/usr/lib/cgi-bin
  sudo cp -fp .github/scripts/php"$PHP_VERSION"-fpm.service "$install_dir"/etc/systemd/system/
  sudo cp -fp .github/scripts/php"$PHP_VERSION".load "$install_dir"/etc/apache2/mods-available/
  sudo mv "$install_dir"/etc/init.d/php-fpm "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo mv "$install_dir/usr/lib/apache2/modules/libphp5.so" "$install_dir/usr/lib/apache2/modules/libphp$PHP_VERSION.so"
  sudo sed -Ei "s|php-fpm.pid|php$PHP_VERSION-fpm.pid|" "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo sed -Ei -e "s|^listen = .*|listen = /run/php/php$PHP_VERSION-fpm.sock|" -e 's|;listen.owner.*|listen.owner = www-data|' -e 's|;listen.group.*|listen.group = www-data|' -e 's|;listen.mode.*|listen.mode = 0660|' -e "s|;pid.*|pid = /run/php/php$PHP_VERSION-fpm.pid|" -e "s|;error_log.*|error_log = /var/log/php$PHP_VERSION-fpm.log|" "$install_dir"/etc/php-fpm.conf
}

build_apache_fpm() {
  export PHP_BUILD_APXS="/usr/bin/apxs2"
  cp /usr/local/share/php-build/default_configure_options.bak /usr/local/share/php-build/default_configure_options
  sudo mkdir -p "$install_dir" "$install_dir"/etc/apache2/mods-available "$install_dir"/etc/apache2/sites-available $install_dir/usr/lib/cgi-bin /usr/local/ssl /var/lib/apache2 /run/php/
  sudo chmod -R 777 /usr/local/php /usr/local/ssl /usr/include/apache2 /usr/lib/apache2 /etc/apache2/ /var/lib/apache2 /var/log/apache2
  configure_apache_fpm_opts
  build_php
  configure_apache_fpm
  mv "$install_dir" "$install_dir-fpm"
}

build_php() {
  export PHP_BUILD_ZTS_ENABLE=off
  if ! php-build -v -i production "$PHP_VERSION" "$install_dir"; then
    echo 'Failed to build PHP'
    exit 1
  fi
}

merge_sapi() {
  mv "$install_dir-fpm" "$install_dir"
  cp "$install_dir-embed/lib/libphp5.so" "$install_dir/usr/lib/libphp$PHP_VERSION.so"
  sudo sed -i 's/php_sapis=" apache2handler cli fpm cgi"/php_sapis=" apache2handler cli fpm cgi embed"/' "$install_dir"/bin/php-config
  cp -a "$install_dir-embed/include/php/sapi" "$install_dir/include/php"
}

configure_php() {
  sudo chmod 777 "$install_dir"/etc/php.ini
  (
    echo "date.timezone=UTC"
    echo "memory_limit=-1"
  ) >>"$install_dir"/etc/php.ini
  setup_pear
  sudo ln -sf "$install_dir"/bin/* /usr/bin/
  sudo ln -sf "$install_dir"/etc/php.ini /etc/php.ini
}

build_extensions() {
  bash .github/scripts/build_extensions.sh
}

build_and_ship_package() {
  bash .github/scripts/install_zstd.sh
  cd "$install_dir"/.. || exit
  sudo tar cf - "$PHP_VERSION" | zstd -22 -T0 --ultra > php-"$PHP_VERSION"-build.tar.zst
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -X DELETE https://api.bintray.com/content/"$BINTRAY_USER"/"$BINTRAY_REPO"/php-"$PHP_VERSION"-build.tar.zst || true
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -T php-"$PHP_VERSION"-build.tar.zst https://api.bintray.com/content/shivammathur/php/"$PHP_VERSION"-linux/"$PHP_VERSION"/php-"$PHP_VERSION"-build.tar.zst || true
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -X POST https://api.bintray.com/content/"$BINTRAY_USER"/"$BINTRAY_REPO"/"$PHP_VERSION"-linux/"$PHP_VERSION"/publish || true
}

mode="${1:-all}"
install_dir=/usr/local/php/"$PHP_VERSION"
tries=10

if [[ "$mode" = "all" || "$mode" = "build" ]]; then
  sudo mkdir -p "$install_dir" /usr/local/ssl
  sudo chmod -R 777 /usr/local/php /usr/local/ssl
  setup_phpbuild
  build_embed
  build_apache_fpm
  merge_sapi
  configure_php
  build_extensions
fi

if [[ "$mode" = "all" || "$mode" = "ship" ]]; then
  build_and_ship_package
fi
