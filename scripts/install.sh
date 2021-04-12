#!/usr/bin/env bash

get() {
  file_path=$1
  shift
  links=("$@")
  for link in "${links[@]}"; do
    status_code=$(sudo curl -w "%{http_code}" -o "$file_path" -sL "$link")
    [ "$status_code" = "200" ] && break
  done
}

install() {
  get "/tmp/$tar_file" "https://github.com/shivammathur/php5-ubuntu/releases/download/builds/$tar_file"
  sudo tar -I zstd -xf "/tmp/$tar_file" -C /tmp
  (
    cd "$php_dir" || exit
    sudo chmod a+x ./*.sh
    ./install-php.sh
    ./post-install.sh
  )
}

tar_file="php-$1.tar.zst"
php_dir="/tmp/php-$1"
install
