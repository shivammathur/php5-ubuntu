ARG UBUNTU_VERSION=ubuntu:trusty
ARG PHP_VERSION=5.3
FROM $UBUNTU_VERSION AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

# Stage that can be used to fetch foreign files
FROM base AS fetch
RUN apt-get update && apt-get install -y wget ca-certificates \
    && sed -i '/^mozilla\/DST_Root_CA_X3/s/^/!/' /etc/ca-certificates.conf \
    && update-ca-certificates -f

# Install required packages
FROM base AS deps
RUN apt-get update && apt-get install -y --no-install-recommends sudo curl software-properties-common
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y --no-install-recommends apache2-mpm-prefork apache2-dev build-essential automake autoconf bison chrpath dpkg-dev flex bzip2 git m4 make libstdc++6-4.7-dev gcc-4.7 g++-4.7 gettext expect imagemagick libmagickwand-dev locales language-pack-de re2c mysql-server postgresql pkg-config libc-client2007e-dev libcurl4-gnutls-dev libacl1-dev libapache2-mod-php5 libapr1-dev libasn1-8-heimdal libattr1-dev libblkid1 libbz2-dev libc6 libcap2 libc-bin libclass-isa-perl libcomerr2 libdb-dev libdbus-1-3 libdebian-installer4 libevent-dev libexpat1-dev libenchant-dev libffi-dev libfreetype6-dev libgcc1 libgcrypt11-dev libgearman-dev libqdbm-dev libglib2.0-0 libgnutls-dev libgpg-error0 libgssapi3-heimdal libgssapi-krb5-2 libgmp-dev libhcrypto4-heimdal libheimbase1-heimdal libheimntlm0-heimdal libhx509-5-heimdal libidn11-dev libk5crypto3 libkeyutils1 libklibc libkrb5-26-heimdal libkrb5-dev libkrb5support0 libldb-dev libldap2-dev libltdl-dev liblzma-dev libmagic-dev libmount-dev libonig-dev libmysqlclient-dev libncurses5-dev libncursesw5 libnewt-dev libnih-dev libnih-dbus1 libodbc1 libp11-kit0 libpam0g libpam-modules libpam-modules-bin libpciaccess0 libpcre3-dev libplymouth-dev libpng12-dev libjpeg-dev libmcrypt-dev libmhash-dev libpspell-dev libpthread-stubs0-dev libpq-dev libreadline-dev librecode-dev libroken18-heimdal libsasl2-dev libselinux1-dev libslang2-dev libsqlite0-dev libsqlite3-dev libssl-dev libswitch-perl libsybdb5 libtasn1-6 libtextwrap-dev libtidy-dev libtinfo-dev libudev-dev libuuid1 libwind0-heimdal libxml2-dev libxpm-dev libxslt1-dev libzip-dev unixodbc-dev zlib1g
RUN set -x \
    && arch="$(uname -m)" \
	&& sed -i '/^mozilla\/DST_Root_CA_X3/s/^/!/' /etc/ca-certificates.conf \
	&& update-ca-certificates -f \
	&& update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 4 \
	&& update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.7 4 \
	&& find /usr/lib/"$arch"-linux-gnu -maxdepth 1 -name "*.so" -printf "%f\n" | xargs -I@ ln -sf /usr/lib/"$arch"-linux-gnu/@ /usr/lib/@ \
	&& ln -sf /usr/lib/libc-client.so.2007e.0 /usr/lib/"$arch"-linux-gnu/libc-client.a \
	&& mkdir -p /usr/c-client/ /usr/include/freetype2/freetype \
	&& ln -sf /usr/lib/libc-client.so.2007e.0 /usr/c-client/libc-client.a \
	&& ln -sf /usr/include/qdbm/* /usr/include/ \
	&& ln -sf /usr/include/"$arch"-linux-gnu/gmp.h /usr/include/gmp.h \
	&& ln -sf /usr/include/freetype2/freetype.h /usr/include/freetype2/freetype/freetype.h \
	&& exit 0

# Build: dependencies
FROM deps AS build-deps-prepare
COPY scripts/build-deps.sh /

FROM build-deps-prepare AS build-bison
RUN bash -xeu /build-deps.sh bison /build
FROM build-deps-prepare AS build-icu
RUN bash -xeu /build-deps.sh icu /build
FROM build-deps-prepare AS build-openssl
RUN bash -xeu /build-deps.sh openssl /build

# Merge layers
FROM deps AS build-deps
COPY --from=build-bison /build /
COPY --from=build-icu /build /
COPY --from=build-openssl /build /

# Fetch php source
FROM fetch AS fetch-php-5.3
WORKDIR /tmp/php-build/packages
RUN wget https://secure.php.net/distributions/php-5.3.29.tar.bz2

FROM fetch AS fetch-php-5.4
WORKDIR /tmp/php-build/packages
RUN wget https://secure.php.net/distributions/php-5.4.45.tar.bz2

FROM fetch AS fetch-php-5.5
WORKDIR /tmp/php-build/packages
RUN wget https://secure.php.net/distributions/php-5.5.38.tar.bz2

FROM fetch-php-$PHP_VERSION AS fetch-php

FROM build-deps AS build-prepare
ARG PHP_VERSION
ENV PHP_VERSION $PHP_VERSION
COPY --from=fetch-php /tmp/php-build/packages/php-*.tar.bz2 /tmp/php-build/packages/

COPY scripts/ /scripts/
COPY conf/ /conf/
COPY php-build/ /php-build/

RUN bash -xeu /scripts/clone-phpbuild.sh
RUN bash -xeu /scripts/setup-phpbuild.sh
RUN bash -xeu /scripts/version-files.sh $PHP_VERSION

FROM build-prepare AS build-embed
RUN bash -xeu /scripts/build.sh build-embed

FROM build-prepare AS build-fpm
RUN bash -xeu /scripts/build.sh build-fpm

FROM build-prepare AS php-build
COPY --from=build-embed /usr/local/php/${PHP_VERSION}-embed /usr/local/php/${PHP_VERSION}-embed
COPY --from=build-fpm /usr/local/php/${PHP_VERSION}-fpm /usr/local/php/${PHP_VERSION}-fpm
RUN bash -xeu /scripts/build.sh merge-sapi

FROM php-build AS build-extensions-prepare
FROM build-extensions-prepare AS ext-apcu
RUN bash -xeu /scripts/build-extensions.sh apcu /build
FROM build-extensions-prepare AS ext-amqp
RUN bash -xeu /scripts/build-extensions.sh amqp /build
FROM build-extensions-prepare AS ext-gearman
RUN bash -xeu /scripts/build-extensions.sh gearman /build
FROM build-extensions-prepare AS ext-imagick
RUN bash -xeu /scripts/build-extensions.sh imagick /build
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/librabbitmq/include
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/librabbitmq/lib/*.la
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/librabbitmq/lib/pkgconfig
FROM build-extensions-prepare AS ext-memcached
RUN bash -xeu /scripts/build-extensions.sh memcached /build
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/bin
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/share/man
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/include
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/lib/lib*.a
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/lib/lib*.la
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/lib/pkgconfig
RUN rm -rf /build/usr/local/php/$PHP_VERSION/lib/libmemcached/share/aclocal
FROM build-extensions-prepare AS ext-memcache
RUN bash -xeu /scripts/build-extensions.sh memcache /build
FROM build-extensions-prepare AS ext-mongo
RUN bash -xeu /scripts/build-extensions.sh mongo /build
FROM build-extensions-prepare AS ext-mongodb
RUN bash -xeu /scripts/build-extensions.sh mongodb /build
FROM build-extensions-prepare AS ext-msgpack
RUN bash -xeu /scripts/build-extensions.sh msgpack /build
FROM build-extensions-prepare AS ext-opcache
RUN bash -xeu /scripts/build-extensions.sh opcache /build
FROM build-extensions-prepare AS ext-propro
RUN bash -xeu /scripts/build-extensions.sh propro /build
FROM build-extensions-prepare AS ext-raphf
RUN bash -xeu /scripts/build-extensions.sh raphf /build
FROM build-extensions-prepare AS ext-redis
RUN bash -xeu /scripts/build-extensions.sh igbinary /build && \
    bash -xeu /scripts/build-extensions.sh redis /build
FROM build-extensions-prepare AS ext-pecl_http
RUN bash -xeu /scripts/build-extensions.sh propro /build && \
    bash -xeu /scripts/build-extensions.sh raphf /build && \
    bash -xeu /scripts/build-extensions.sh pecl_http /build

FROM php-build
COPY --from=ext-apcu /build /
COPY --from=ext-amqp /build /
COPY --from=ext-gearman /build /
COPY --from=ext-imagick /build /
COPY --from=ext-memcached /build /
COPY --from=ext-memcache /build /
COPY --from=ext-mongo /build /
COPY --from=ext-mongodb /build /
COPY --from=ext-msgpack /build /
COPY --from=ext-opcache /build /
COPY --from=ext-redis /build /
COPY --from=ext-pecl_http /build /
