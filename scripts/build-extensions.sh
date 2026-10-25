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
  cp /backport-extensions/amqp-1.9.3.tgz /tmp/amqp.tgz
  tar -xzf /tmp/amqp.tgz -C /tmp
  build_extension amqp /tmp/amqp-"$AMQP_VERSION" extension 20 --with-amqp=shared --with-librabbitmq-dir="$install_dir"/lib/librabbitmq
}

add_apcu() {
  cp /backport-extensions/apcu-4.0.11.tgz /tmp/apcu.tgz
  tar -xzf /tmp/apcu.tgz -C /tmp
  build_extension apcu /tmp/apcu-"$APCU_VERSION" extension 20 --enable-apcu
}

add_gearman() {
  cp /backport-extensions/gearman-1.1.0.tgz /tmp/gearman.tgz
  tar -xzf /tmp/gearman.tgz -C /tmp
  build_extension gearman /tmp/gearman-"$GEARMAN_VERSION" extension 20 --with-gearman=/usr
}

add_igbinary() {
  cp /backport-extensions/igbinary-2.0.8.tgz /tmp/igbinary.tgz
  tar -xzf /tmp/igbinary.tgz -C /tmp
  build_extension igbinary /tmp/igbinary-"$IGBINARY_VERSION" extension 20
}

add_imagick() {
  cp /backport-extensions/imagick-3.4.4.tgz /tmp/imagick.tgz
  tar -xzf /tmp/imagick.tgz -C /tmp
  build_extension imagick /tmp/imagick-"$IMAGICK_VERSION" extension 20
}

add_memcached() {
  add_libmemcached
  cp /backport-extensions/memcached-2.2.0.tgz /tmp/memcached.tgz
  tar -xzf /tmp/memcached.tgz -C /tmp
  build_extension memcached /tmp/memcached-"$MEMCACHED_VERSION" extension 25 --enable-memcached --with-libmemcached-dir="$install_dir"/lib/libmemcached
}

add_memcache() {
  cp /backport-extensions/memcache-3.0.8.tgz /tmp/memcache.tgz
  tar -xzf /tmp/memcache.tgz -C /tmp
  build_extension memcache /tmp/memcache-"$MEMCACHE_VERSION" extension 20 --enable-memcache
}

add_mongo() {
  cp /backport-extensions/mongo-1.6.16.tgz /tmp/mongo.tgz
  tar -xzf /tmp/mongo.tgz -C /tmp
  build_extension mongo /tmp/mongo-"$MONGO_VERSION" extension 20 --enable-mongo
}

add_mongodb() {
  cp /backport-extensions/mongodb-1.1.0.tgz /tmp/mongodb.tgz
  tar -xzf /tmp/mongodb.tgz -C /tmp
  build_extension mongodb /tmp/mongodb-"$MONGODB_VERSION" extension 20 --enable-mongodb
}

add_msgpack() {
  cp /backport-extensions/msgpack-0.5.7.tgz /tmp/msgpack.tgz
  tar -xzf /tmp/msgpack.tgz -C /tmp
  build_extension msgpack /tmp/msgpack-"$MSGPACK_VERSION" extension 20 --with-msgpack
}

add_opcache() {
  if [ "$PHP_VERSION" != "5.5" ]; then
    cp /backport-extensions/zendopcache-7.0.5.tgz /tmp/opcache.tgz
    tar -xzf /tmp/opcache.tgz -C /tmp
    build_extension opcache /tmp/zendopcache-"$OPCACHE_VERSION" zend_extension 10 --enable-opcache
  fi
}

add_pecl_http() {
  cp /backport-extensions/pecl_http-2.6.0.tgz /tmp/pecl_http.tgz
  tar -xzf /tmp/pecl_http.tgz -C /tmp
  build_extension pecl_http /tmp/pecl_http-"$PECL_HTTP_VERSION" extension 25 --with-http --with-http-zlib-dir=/usr --with-http-libcurl-dir=/usr --with-http-libevent-dir=/usr --with-http-libidn-dir=/usr
}

add_propro() {
  cp /backport-extensions/propro-1.0.2.tgz /tmp/propro.tgz
  tar -xzf /tmp/propro.tgz -C /tmp
  build_extension propro /tmp/propro-"$PROPRO_VERSION" extension 20 --enable-propro
}

add_raphf() {
  cp /backport-extensions/raphf-1.1.2.tgz /tmp/raphf.tgz
  tar -xzf /tmp/raphf.tgz -C /tmp
  build_extension raphf /tmp/raphf-"$RAPHF_VERSION" extension 20 --enable-raphf
}

add_redis() {
  cp /backport-extensions/redis-2.2.8.tgz /tmp/redis.tgz
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
