setup_phpbuild() {
  echo "::group::phpbuild"
  (
    cd ~ || exit
    git clone git://github.com/php-build/php-build
    cd php-build || exit
    sudo ./install.sh
  )
  sudo cp .github/scripts/5.3 /usr/local/share/php-build/definitions/
  sudo cp .github/scripts/php-5.3.29-multi-sapi.patch /usr/local/share/php-build/patches/
  cp /usr/local/share/php-build/default_configure_options /usr/local/share/php-build/default_configure_options.bak
  echo "::endgroup::"
}

setup_pear() {
  echo "::group::pear"
  sudo rm -rf "$install_dir"/bin/pear "$install_dir"/bin/pecl
  sudo curl -fsSL --retry "$tries" -o /usr/local/ssl/cert.pem https://curl.haxx.se/ca/cacert.pem
  sudo curl -fsSL --retry "$tries" -O https://github.com/pear/pearweb_phars/raw/v1.9.7/go-pear.phar
  sudo chmod a+x .github/scripts/install-pear.expect
  .github/scripts/install-pear.expect "$install_dir"
  rm go-pear.phar
  sudo "$install_dir"/bin/pear config-set php_ini "$install_dir"/etc/php.ini system
  sudo "$install_dir"/bin/pear channel-update pear.php.net
  echo "::endgroup::"
}

build_embed() {
  echo "::group::embed"
  cp /usr/local/share/php-build/default_configure_options.bak /usr/local/share/php-build/default_configure_options
  sudo sed -i "/apxs2/d" /usr/local/share/php-build/definitions/"$PHP_VERSION" || true
  sudo sed -i "/fpm/d" /usr/local/share/php-build/default_configure_options || true
  sudo sed -i "/cgi/d" /usr/local/share/php-build/default_configure_options || true
  echo "--enable-embed=shared" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  build_php
  mv "$install_dir" "$install_dir-embed"
  echo "::endgroup::"
}

build_apache_fpm() {
  echo "::group::apachefpm"
  export PHP_BUILD_APXS="/usr/bin/apxs2"
  cp /usr/local/share/php-build/default_configure_options.bak /usr/local/share/php-build/default_configure_options
  sudo mkdir -p "$install_dir" "$install_dir"/etc/apache2/mods-available /usr/local/ssl /var/lib/apache2 /run/php/
  sudo chmod -R 777 /usr/local/php /usr/local/ssl /usr/include/apache2 /usr/lib/apache2 /etc/apache2/ /var/lib/apache2 /var/log/apache2
  sudo sed -i "/cgi/d" /usr/local/share/php-build/default_configure_options
  sudo sed -i '1iconfigure_option "--with-apxs2" "/usr/bin/apxs2"' /usr/local/share/php-build/definitions/"$PHP_VERSION"
  echo "--enable-cgi" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--enable-fpm" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--with-fpm-user=www-data" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  echo "--with-fpm-group=www-data" | sudo tee -a /usr/local/share/php-build/default_configure_options >/dev/null 2>&1
  build_php
  sudo ln -sv "$install_dir"/sbin/php-fpm "$install_dir"/bin/php-fpm
  sudo mkdir -p "$install_dir"/etc/systemd/system
  sudo sed -Ei "s|^listen = .*|listen = /run/php/php$PHP_VERSION-fpm.sock|" "$install_dir"/etc/php-fpm.conf
  sudo sed -Ei 's|;listen.owner.*|listen.owner = www-data|' "$install_dir"/etc/php-fpm.conf
  sudo sed -Ei 's|;listen.group.*|listen.group = www-data|' "$install_dir"/etc/php-fpm.conf
  sudo sed -Ei 's|;listen.mode.*|listen.mode = 0660|' "$install_dir"/etc/php-fpm.conf
  sudo sed -Ei "s|;pid.*|pid = /run/php/php$PHP_VERSION-fpm.pid|" "$install_dir"/etc/php-fpm.conf
  sudo sed -Ei "s|;error_log.*|error_log = /var/log/php$PHP_VERSION-fpm.log|" "$install_dir"/etc/php-fpm.conf
  sudo cp -fp .github/scripts/fpm.service "$install_dir"/etc/systemd/system/php-fpm.service
  sudo cp -fp .github/scripts/php-fpm-socket-helper "$install_dir"/bin/
  sudo chmod a+x "$install_dir"/bin/php-fpm-socket-helper
  sudo mv "$install_dir/usr/lib/apache2/modules/libphp5.so" "$install_dir/usr/lib/apache2/modules/libphp5.3.so"
  echo "LoadModule php5_module $install_dir/usr/lib/apache2/modules/libphp5.3.so" | sudo tee /etc/apache2/mods-available/php5.3.load >/dev/null 2>&1
  echo "LoadModule php5_module $install_dir/usr/lib/apache2/modules/libphp5.3.so" | sudo tee "$install_dir"/etc/apache2/mods-available/php5.3.load >/dev/null 2>&1
  sudo cp -fp .github/scripts/apache.conf /etc/apache2/mods-available/php"$PHP_VERSION".conf
  sudo cp -fp .github/scripts/apache.conf "$install_dir"/etc/apache2/mods-available/php"$PHP_VERSION".conf
  sudo a2dismod php5 || true
  sudo mkdir -p /lib/systemd/system
  sudo mv "$install_dir"/etc/init.d/php-fpm "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo sed -Ei "s|php-fpm.pid|php$PHP_VERSION-fpm.pid|" "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo cp -fp "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm /etc/init.d/php"$PHP_VERSION"-fpm
  sudo cp -fp "$install_dir"/etc/systemd/system/php-fpm.service /lib/systemd/system/php"$PHP_VERSION"-fpm.service
  sudo /etc/init.d/php"$PHP_VERSION"-fpm start || true
  mv "$install_dir" "$install_dir-fpm"
  echo "::endgroup::"
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
  cp "$install_dir-embed/lib/libphp5.so" "$install_dir/lib/"
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
  cd "$install_dir"/.. || exit
  bash .github/scripts/install_zstd.sh
  export GZIP=-9
  tar -czf php53.tar.gz "$PHP_VERSION"
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -X DELETE https://api.bintray.com/content/"$BINTRAY_USER"/"$BINTRAY_REPO"/php53.tar.gz || true
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -T php53.tar.gz https://api.bintray.com/content/shivammathur/php/5.3-linux/5.3/php53.tar.gz || true
  curl --user "$BINTRAY_USER":"$BINTRAY_KEY" -X POST https://api.bintray.com/content/"$BINTRAY_USER"/"$BINTRAY_REPO"/5.3-linux/5.3/publish || true
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
