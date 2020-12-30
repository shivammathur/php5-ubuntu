build_extension() {
  extension=$1
  source_dir=$2
  shift 2
  args=("$@")
  echo "::group::$extension"
  (
    cd "$source_dir" || exit
    phpize
    sudo ./configure "${args[@]}" --with-php-config="$install_dir"/bin/php-config
    sudo make -j"$(nproc)"
    sudo cp ./modules/"$extension".so "$ext_dir"/"$extension".so
    echo "extension=$extension.so" | sudo tee "$install_dir/etc/conf.d/$extension.ini"
  )
  echo "::endgroup::"
}

build_lib() {
  lib=$1
  source_dir=$2
  shift 2
  args=("$@")
  echo "::group::$lib"
  mkdir "$install_dir"/lib/"$lib"
  (
    cd "$source_dir" || exit
    sudo ./configure --prefix="$install_dir"/lib/"$lib" "${args[@]}"
    sudo make -j"$(nproc)"
    sudo make install
  )
  echo "::endgroup::"
}

add_autoconf() {
  curl -o /tmp/autoconf.tar.gz -sL https://ftp.gnu.org/gnu/autoconf/autoconf-"$AUTOCONF_VERSION".tar.gz
  tar -xzf /tmp/autoconf.tar.gz -C /tmp
  echo "::group::autoconf"
  (
    cd /tmp/autoconf-"$AUTOCONF_VERSION" || exit 1
    sudo ./configure --prefix=/usr
    sudo make -j"$(nproc)"
    sudo make install
  )
  echo "::endgroup::"
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

add_apcu() {
  curl -o /tmp/apcu.tgz -sL https://pecl.php.net/get/apcu-"$APCU_VERSION".tgz
  tar -xzf /tmp/apcu.tgz -C /tmp
  build_extension apcu /tmp/apcu-"$APCU_VERSION" --enable-apcu
}

add_amqp() {
  add_librabbitmq
  curl -o /tmp/amqp.tgz -sL https://pecl.php.net/get/amqp-"$AMQP_VERSION".tgz
  tar -xzf /tmp/amqp.tgz -C /tmp
  build_extension amqp /tmp/amqp-"$AMQP_VERSION" --with-amqp=shared --with-librabbitmq-dir="$install_dir"/lib/librabbitmq
}

add_memcached() {
  add_libmemcached
  curl -o /tmp/memcached.tgz -sL https://pecl.php.net/get/memcached-"$MEMCACHED_VERSION".tgz
  tar -xzf /tmp/memcached.tgz -C /tmp
  build_extension memcached /tmp/memcached-"$MEMCACHED_VERSION" --enable-memcached --with-libmemcached-dir="$install_dir"/lib/libmemcached
}

add_memcache() {
  curl -o /tmp/memcache.tgz -sL https://pecl.php.net/get/memcache-"$MEMCACHE_VERSION".tgz
  tar -xzf /tmp/memcache.tgz -C /tmp
  build_extension memcache /tmp/memcache-"$MEMCACHE_VERSION" --enable-memcache
}

add_mongo() {
  curl -o /tmp/mongo.tgz -sL https://pecl.php.net/get/mongo-"$MONGO_VERSION".tgz
  tar -xzf /tmp/mongo.tgz -C /tmp
  build_extension mongo /tmp/mongo-"$MONGO_VERSION" --enable-mongo
}

add_mongodb() {
  curl -o /tmp/mongodb.tgz -sL https://pecl.php.net/get/mongodb-"$MONGODB_VERSION".tgz
  tar -xzf /tmp/mongodb.tgz -C /tmp
  build_extension mongodb /tmp/mongodb-"$MONGODB_VERSION" --enable-mongodb
}

add_redis() {
  curl -o /tmp/redis.tgz -sL https://pecl.php.net/get/redis-"$REDIS_VERSION".tgz
  tar -xzf /tmp/redis.tgz -C /tmp
  build_extension redis /tmp/redis-"$REDIS_VERSION" --enable-redis
}

AUTOCONF_VERSION='2.68'
PHP_VERSION='5.3'
APCU_VERSION='4.0.11'
AMQP_VERSION='1.9.3'
MEMCACHED_VERSION='2.2.0'
MEMCACHE_VERSION='3.0.8'
MONGO_VERSION='1.6.16'
MONGODB_VERSION='1.1.0'
REDIS_VERSION='2.2.8'
LIBMEMCACHED_VERSION='1.0.18'
LIBRABBITMQ_VERSION='0.8.0'
install_dir=/usr/local/php/"$PHP_VERSION"
ext_dir=$("$install_dir"/bin/php -i | grep "extension_dir => /" | sed -e "s|.*=> s*||")
add_autoconf
add_apcu
add_amqp
add_memcached
add_memcache
add_mongo
add_mongodb
add_redis
