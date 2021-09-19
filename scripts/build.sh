#!/bin/bash

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")

clone_phpbuild() {
  "$SCRIPT_DIR"/clone-phpbuild.sh
}

setup_phpbuild() {
  "$SCRIPT_DIR"/setup-phpbuild.sh
}

version_files() {
  "$SCRIPT_DIR"/version-files.sh "$PHP_VERSION"
}

get_buildflags() {
  type=$1
  debug=${2:-false}
  lto=${3:--lto}
  flags=$(dpkg-buildflags --get "$type")

  # Add or remove flag for debug symbols.
  if [ "$debug" = "false" ]; then
    flags=${flags/-g/}
  else
    flags="$flags -g"
  fi

  # Add or remove lto optimization flags.
  if [ "$lto" = "-lto" ]; then
    flags=$(echo "$flags" | sed -E 's/[^ ]+lto[^ ]+ //g')
  else
    flags="$flags -flto=auto -ffat-lto-objects"
  fi

  echo "$flags"
}

pear_version() {
  if [ "$PHP_VERSION" = "5.3" ]; then
    echo v1.9.7
  else
    echo master
  fi
}

setup_pear() {
  sudo rm -rf "$install_dir"/bin/pear "$install_dir"/bin/pecl
  sudo mkdir -p /usr/local/ssl
  sudo chmod -R 777 /usr/local/ssl
  sudo curl -fsSL --retry "$tries" -o /usr/local/ssl/cert.pem https://curl.haxx.se/ca/cacert.pem
  sudo curl -fsSL --retry "$tries" -O https://github.com/pear/pearweb_phars/raw/"$(pear_version)"/go-pear.phar
  sudo chmod a+x scripts/install-pear.expect
  scripts/install-pear.expect "$install_dir"
  # Patch pear binaries to check extensions without -n as xml is built as a shared extension.
  sed -i "s|\-n||g" "$install_dir"/bin/pecl "$install_dir"/bin/pear "$install_dir"/bin/peardev
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
  sudo ln -sv "$install_dir"/bin/php-cgi "$install_dir"/usr/lib/cgi-bin/php"$PHP_VERSION"
  sudo mkdir -p "$install_dir"/etc/systemd/system "$install_dir"/usr/lib/cgi-bin
  sudo cp -fp conf/php"$PHP_VERSION"-fpm.service "$install_dir"/etc/systemd/system/
  sudo cp -fp conf/php"$PHP_VERSION".load "$install_dir"/etc/apache2/mods-available/
  sudo mv "$install_dir"/etc/init.d/php-fpm "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo mv "$install_dir/usr/lib/apache2/modules/libphp5.so" "$install_dir/usr/lib/apache2/modules/libphp$PHP_VERSION.so"
  sudo sed -Ei "s|php-fpm.pid|php$PHP_VERSION-fpm.pid|" "$install_dir"/etc/init.d/php"$PHP_VERSION"-fpm
  sudo sed -Ei -e "s|^listen = .*|listen = /run/php/php$PHP_VERSION-fpm.sock|" -e 's|;listen.owner.*|listen.owner = www-data|' -e 's|;listen.group.*|listen.group = www-data|' -e 's|;listen.mode.*|listen.mode = 0660|' -e "s|;pid.*|pid = /run/php/php$PHP_VERSION-fpm.pid|" -e "s|;error_log.*|error_log = /var/log/php$PHP_VERSION-fpm.log|" "$install_dir"/etc/php-fpm.conf
}

build_apache_fpm() {
  export PHP_BUILD_APXS="/usr/bin/apxs2"
  export APACHE_CONFDIR="/etc/apache2"
  . /etc/apache2/envvars
  cp /usr/local/share/php-build/default_configure_options.bak /usr/local/share/php-build/default_configure_options
  sudo mkdir -p "$install_dir" "$install_dir"/etc/apache2/mods-available "$install_dir"/etc/apache2/sites-available "$install_dir"/usr/lib/cgi-bin /usr/local/ssl /var/lib/apache2 /run/php/
  sudo chmod -R 777 /usr/local/php /usr/local/ssl /usr/include/apache2 /usr/lib/apache2 /etc/apache2/ /var/lib/apache2 /var/log/apache2
  configure_apache_fpm_opts
  build_php
  configure_apache_fpm
  mv "$install_dir" "$install_dir-fpm"
}

build_php() {
  # Set and export FLAGS
  CFLAGS="$(get_buildflags CFLAGS "$debug" "$lto") $(getconf LFS_CFLAGS)"
  CPPFLAGS="$(get_buildflags CPPFLAGS "$debug" "$lto")"
  CXXFLAGS="$(get_buildflags CXXFLAGS "$debug" "$lto")"
  LDFLAGS="$(get_buildflags LDFLAGS "$debug" "$lto") -Wl,-z,now -Wl,--as-needed -pthread"
  EXTRA_CFLAGS="-Wall -fsigned-char -fno-strict-aliasing -Wno-missing-field-initializers -pthread"
  PHP_BUILD_ZTS_ENABLE=off
  export CFLAGS
  export CPPFLAGS
  export CXXFLAGS
  export LDFLAGS
  export EXTRA_CFLAGS
  export PHP_BUILD_ZTS_ENABLE
  if ! php-build -v -i production "$PHP_VERSION" "$install_dir"; then
    echo 'Failed to build PHP'
    exit 1
  fi
}

configure_extensions() {
  ext_dir=$("$install_dir"/bin/php -i | grep "extension_dir => /" | sed -e "s|.*=> s*||")
  rm -rf "$install_dir"/etc/conf.d/*.ini
  for extension_path in "$ext_dir"/*.so; do
    extension="$(basename "$extension_path" | cut -d '.' -f 1)"
    priority='20'
    [[ "$extension" =~ ^(pdo|mysqlnd)$ ]] && priority='10'
    [ "$extension" = 'xml' ] && priority='15'
    prefix='extension'
    [[ "$extension" =~ ^(xdebug|opcache)$ ]] && prefix='zend_extension'
    if ! [ -e "$install_dir/etc/conf.d/$priority-$extension.ini" ]; then
      echo "$prefix=$ext_dir/$extension.so" | sudo tee "$install_dir/etc/conf.d/$priority-$extension.ini"
    fi
  done
}

merge_sapi() {
  rm -rf "$install_dir"
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
  configure_extensions
  setup_pear
  sudo ln -sf "$install_dir"/bin/* /usr/bin/
  sudo ln -sf "$install_dir"/etc/php.ini /etc/php.ini
}

build_extensions() {
  bash scripts/build-extensions.sh
}

build_and_ship_package() {
  bash scripts/install-zstd.sh
  (
    cd "$install_dir"/.. || exit
    sudo tar cf - "$PHP_VERSION" | zstd -22 -T0 --ultra > "$GITHUB_WORKSPACE"/php-"$PHP_VERSION"-build.tar.zst
  )
  gh release download -p "release.log" || true
  echo "$(date "+%Y-%m-%d %H:%M:%S") Update php-$PHP_VERSION-build.tar.zst" | sudo tee -a release.log >/dev/null 2>&1
  gh release upload "builds" release.log "php-$PHP_VERSION-build.tar.zst" --clobber
}

mode="${1:-all}"
install_dir=/usr/local/php/"$PHP_VERSION"
debug=false
lto=-lto
tries=10

if [[ "$mode" = "all" || "$mode" = "version-files" ]]; then
  version_files
fi

if [[ "$mode" = "all" || "$mode" = "php-build" ]]; then
  clone_phpbuild
fi

if [[ "$mode" = "all" || "$mode" = "setup-phpbuild" ]]; then
  sudo mkdir -p "$install_dir" /usr/local/ssl
  sudo chmod -R 777 /usr/local/php /usr/local/ssl
  setup_phpbuild
fi

if [[ "$mode" = "all" || "$mode" = "build-embed" ]]; then
  build_embed
fi

if [[ "$mode" = "all" || "$mode" = "build-fpm" ]]; then
  build_apache_fpm
fi

if [[ "$mode" = "all" || "$mode" = "merge-sapi" ]]; then
  merge_sapi
  configure_php
fi

if [[ "$mode" = "all" || "$mode" = "build-extensions" ]]; then
  build_extensions
fi

if [[ "$mode" = "all" || "$mode" = "ship" ]]; then
  build_and_ship_package
fi