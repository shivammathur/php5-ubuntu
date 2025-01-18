build_extension() {
  extension=${1//pecl_}
  source_dir=$2
  prefix=$3
  priority=$4
  shift 4
  args=("${@:-}")
  (
    cd "$source_dir" || exit
    phpize
    fix_config_files
    sudo ./configure "${args[@]}" --with-php-config="$install_dir"/bin/php-config
    sudo make -j"$(nproc)"
    sudo make install
    sudo cp ./modules/"$extension".so "$DESTDIR$ext_dir/$extension".so
    sudo cp ./modules/"$extension".so "$ext_dir/$extension".so
    sudo mkdir -p "$DESTDIR$install_dir/etc/conf.d"
    echo "$prefix=$ext_dir/$extension.so" | sudo tee "$DESTDIR$install_dir/etc/conf.d/$priority-$extension.ini" "$install_dir/etc/conf.d/$priority-$extension.ini"
  )
  sudo rm -rf "$source_dir"
}

build_lib() {
  lib=$1
  source_dir=$2
  shift 2
  mkdir "$install_dir"/lib/"$lib"
  (
    cd "$source_dir" || exit
    fix_config_files
    sudo ./configure --prefix="$install_dir"/lib/"$lib" "$@"
    sudo make -j"$(nproc)"
    sudo make install
    sudo make install DESTDIR="$DESTDIR"
  )
  sudo rm -rf "$source_dir"
}

add_librabbitmq() {
  curl -o /tmp/rabbitmq.tar.gz -sL https://github.com/alanxz/rabbitmq-c/releases/download/v"$LIBRABBITMQ_VERSION"/rabbitmq-c-"$LIBRABBITMQ_VERSION".tar.gz
  tar -xzf /tmp/rabbitmq.tar.gz -C /tmp
  build_lib librabbitmq /tmp/rabbitmq-c-"$LIBRABBITMQ_VERSION"
}

add_libmemcached() {
  curl -o /tmp/memcached.tar.gz -sL https://launchpad.net/libmemcached/1.0/"$LIBMEMCACHED_VERSION"/+download/libmemcached-"$LIBMEMCACHED_VERSION".tar.gz
  tar -xzf /tmp/memcached.tar.gz -C /tmp
  build_lib libmemcached /tmp/libmemcached-"$LIBMEMCACHED_VERSION"
}

add_amqp() {
  add_librabbitmq
  curl -o /tmp/amqp.tgz -sL https://pecl.php.net/get/amqp-"$AMQP_VERSION".tgz
  tar -xzf /tmp/amqp.tgz -C /tmp
  build_extension amqp /tmp/amqp-"$AMQP_VERSION" extension 20 --with-amqp=shared --with-librabbitmq-dir="$install_dir"/lib/librabbitmq
}

add_apcu() {
  curl -o /tmp/apcu.tgz -sL https://pecl.php.net/get/apcu-"$APCU_VERSION".tgz
  tar -xzf /tmp/apcu.tgz -C /tmp
  build_extension apcu /tmp/apcu-"$APCU_VERSION" extension 20 --enable-apcu
}

add_gearman() {
  curl -o /tmp/gearman.tgz -sL https://pecl.php.net/get/gearman-"$GEARMAN_VERSION".tgz
  tar -xzf /tmp/gearman.tgz -C /tmp
  build_extension gearman /tmp/gearman-"$GEARMAN_VERSION" extension 20 --with-gearman=/usr
}

add_igbinary() {
  curl -o /tmp/igbinary.tgz -sL https://pecl.php.net/get/igbinary-"$IGBINARY_VERSION".tgz
  tar -xzf /tmp/igbinary.tgz -C /tmp
  build_extension igbinary /tmp/igbinary-"$IGBINARY_VERSION" extension 20
}

add_imagick() {
  curl -o /tmp/imagick.tgz -sL https://pecl.php.net/get/imagick-"$IMAGICK_VERSION".tgz
  tar -xzf /tmp/imagick.tgz -C /tmp
  build_extension imagick /tmp/imagick-"$IMAGICK_VERSION" extension 20
}

add_memcached() {
  add_libmemcached
  curl -o /tmp/memcached.tgz -sL https://pecl.php.net/get/memcached-"$MEMCACHED_VERSION".tgz
  tar -xzf /tmp/memcached.tgz -C /tmp
  build_extension memcached /tmp/memcached-"$MEMCACHED_VERSION" extension 25 --enable-memcached --with-libmemcached-dir="$install_dir"/lib/libmemcached
}

add_memcache() {
  curl -o /tmp/memcache.tgz -sL https://pecl.php.net/get/memcache-"$MEMCACHE_VERSION".tgz
  tar -xzf /tmp/memcache.tgz -C /tmp
  build_extension memcache /tmp/memcache-"$MEMCACHE_VERSION" extension 20 --enable-memcache
}

add_mongo() {
  curl -o /tmp/mongo.tgz -sL https://pecl.php.net/get/mongo-"$MONGO_VERSION".tgz
  tar -xzf /tmp/mongo.tgz -C /tmp
  build_extension mongo /tmp/mongo-"$MONGO_VERSION" extension 20 --enable-mongo
}

add_mongodb() {
  curl -o /tmp/mongodb.tgz -sL https://pecl.php.net/get/mongodb-"$MONGODB_VERSION".tgz
  tar -xzf /tmp/mongodb.tgz -C /tmp
  build_extension mongodb /tmp/mongodb-"$MONGODB_VERSION" extension 20 --enable-mongodb
}

add_msgpack() {
  curl -o /tmp/msgpack.tgz -sL https://pecl.php.net/get/msgpack-"$MSGPACK_VERSION".tgz
  tar -xzf /tmp/msgpack.tgz -C /tmp
  build_extension msgpack /tmp/msgpack-"$MSGPACK_VERSION" extension 20 --with-msgpack
}

add_opcache() {
  if [ "$PHP_VERSION" != "5.5" ]; then
    curl -o /tmp/opcache.tgz -sL https://pecl.php.net/get/zendopcache-"$OPCACHE_VERSION".tgz
    tar -xzf /tmp/opcache.tgz -C /tmp
    build_extension opcache /tmp/zendopcache-"$OPCACHE_VERSION" zend_extension 10 --enable-opcache
  fi
}

add_pecl_http() {
  curl -o /tmp/pecl_http.tgz -sL https://pecl.php.net/get/pecl_http-"$PECL_HTTP_VERSION".tgz
  tar -xzf /tmp/pecl_http.tgz -C /tmp
  build_extension pecl_http /tmp/pecl_http-"$PECL_HTTP_VERSION" extension 25 --with-http --with-http-zlib-dir=/usr --with-http-libcurl-dir=/usr --with-http-libevent-dir=/usr --with-http-libidn-dir=/usr
}

add_propro() {
  curl -o /tmp/propro.tgz -sL https://pecl.php.net/get/propro-"$PROPRO_VERSION".tgz
  tar -xzf /tmp/propro.tgz -C /tmp
  build_extension propro /tmp/propro-"$PROPRO_VERSION" extension 20 --enable-propro
}

add_raphf() {
  curl -o /tmp/raphf.tgz -sL https://pecl.php.net/get/raphf-"$RAPHF_VERSION".tgz
  tar -xzf /tmp/raphf.tgz -C /tmp
  build_extension raphf /tmp/raphf-"$RAPHF_VERSION" extension 20 --enable-raphf
}

add_redis() {
  curl -o /tmp/redis.tgz -sL https://pecl.php.net/get/redis-"$REDIS_VERSION".tgz
  tar -xzf /tmp/redis.tgz -C /tmp
  build_extension redis /tmp/redis-"$REDIS_VERSION" extension 20 --enable-redis --enable-redis-igbinary
}

fix_config_files() {
  for conf_file in config.guess config.sub; do
    find . -name "$conf_file" -exec cp /usr/share/automake-*/"$conf_file" {} \;
  done
}

PHP_VERSION=${PHP_VERSION:-'5.3'}
APCU_VERSION='4.0.11'
AMQP_VERSION='1.9.3'
GEARMAN_VERSION='1.1.0'
IGBINARY_VERSION='2.0.8'
IMAGICK_VERSION='3.4.4'
MEMCACHED_VERSION='2.2.0'
MEMCACHE_VERSION='3.0.8'
MONGO_VERSION='1.6.16'
MONGODB_VERSION='1.1.0'
MSGPACK_VERSION='0.5.7'
OPCACHE_VERSION='7.0.5'
REDIS_VERSION='2.2.8'
PROPRO_VERSION='1.0.2'
RAPHF_VERSION='1.1.2'
PECL_HTTP_VERSION='2.6.0'
LIBMEMCACHED_VERSION='1.0.18'
LIBRABBITMQ_VERSION='0.8.0'
install_dir=/usr/local/php/"$PHP_VERSION"
ext_dir=$("$install_dir"/bin/php -i | grep "extension_dir => /" | sed -e "s|.*=> s*||")

mode="${1:-all}"
DESTDIR="${2:-}"

mkdir -p "$DESTDIR$ext_dir"
packages=(amqp apcu gearman igbinary imagick memcached memcache mongo mongodb msgpack opcache redis propro raphf pecl_http)
if [ "$mode" = "all" ]; then
  for package in "${packages[@]}"; do
    add_"${package}"
  done
else
  add_"${mode}"
fi
