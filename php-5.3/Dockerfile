ARG UBUNTU_VERSION=precise
FROM ubuntu:$UBUNTU_VERSION AS base

ENV DEBIAN_FRONTEND=noninteractive
RUN LC_ALL=C.UTF-8

# Install required packages
FROM base AS deps
RUN apt-get update && apt-get install -y sudo curl python-software-properties
RUN apt-add-repository ppa:ondrej/php -y
RUN apt-add-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get -y install apache2-mpm-prefork apache2-prefork-dev build-essential checkinstall zlib1g-dev automake autoconf bzip2 git m4 make libstdc++6-4.7-dev gcc-4.7 g++-4.7 gettext expect locales language-pack-de re2c mysql-server postgresql pkg-config libc-client-dev libcurl4-gnutls-dev libacl1-dev libapache2-mod-php5 libapr1-dev libasn1-8-heimdal libattr1-dev libblkid1 libbz2-dev libc6 libcap2 libc-bin libclass-isa-perl libcomerr2 libdb5.1-dev libdbus-1-3 libdebian-installer4 libdrm2 libdrm-intel1 libdrm-nouveau1a libdrm-radeon1 libexpat1-dev libenchant-dev libffi-dev libfreetype6-dev libgcc1 libgcrypt11-dev libgdbm-dev libglib2.0-0 libgnutls-dev libgpg-error0 libgssapi3-heimdal libgssapi-krb5-2 libgmp-dev libhcrypto4-heimdal libheimbase1-heimdal libheimntlm0-heimdal libhx509-5-heimdal libk5crypto3 libkeyutils1 libklibc libkrb5-26-heimdal libkrb5-dev libkrb5support0 libldb-dev libldap-dev libltdl-dev liblzma-dev libmagic-dev libmount-dev libonig-dev libmysqlclient-dev libncurses5-dev libncursesw5 libnewt-dev libnih-dev libnih-dbus1 libodbc1 libp11-kit0 libpam0g libpam-modules libpam-modules-bin libpciaccess0 libpcre3-dev libplymouth-dev libpng-dev libjpeg-dev libmcrypt-dev libmhash-dev libpspell-dev libpq-dev libreadline-dev librecode-dev libroken18-heimdal libsasl2-dev libselinux1-dev libslang2-dev libsqlite3-dev libssl-dev libswitch-perl libsybdb5 libtasn1-3 libtextwrap-dev libtidy-dev libtinfo-dev libudev-dev libuuid1 libwind0-heimdal libxml2-dev libxpm-dev libxslt-dev libzip-dev
RUN set -x \
	&& update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.7 4 \
	&& update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.7 4 \
	&& \
		for lib_link in $(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -name "*.so" -printf "%f\n"); do \
			ln -s /usr/lib/x86_64-linux-gnu/$lib_link /usr/lib/$lib_lin; \
		done \
	&& ln -sf /usr/lib/libc-client.so.2007e.0 /usr/lib/x86_64-linux-gnu/libc-client.a \
	&& mkdir -p /usr/c-client/ \
	&& ln -sf /usr/lib/libc-client.so.2007e.0 /usr/c-client/libc-client.a \
	&& exit 0

# Build: dependencies
FROM deps AS build-deps
COPY .github/scripts/build_deps.sh /
RUN bash -xeu /build_deps.sh autoconf
RUN bash -xeu /build_deps.sh icu
RUN bash -xeu /build_deps.sh bison
RUN bash -xeu /build_deps.sh openssl

FROM build-deps AS build
ARG PHP_VERSION=5.3
ENV PHP_VERSION $PHP_VERSION
COPY .github/scripts/ /.github/scripts/
RUN bash -xeu /.github/scripts/build.sh build
