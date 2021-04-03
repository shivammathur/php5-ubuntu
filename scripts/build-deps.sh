install_pkg() {
  pkg_dir=$1
  (
    cd "$pkg_dir" || exit 1
    sudo ./configure --prefix=/usr
    sudo make -j"$(nproc)"
    sudo make install DESTDIR="$DESTDIR"
  )
}

add_autoconf() {
  curl -o /tmp/autoconf.tar.gz -sL https://ftp.gnu.org/gnu/autoconf/autoconf-2.59.tar.gz
  tar -xzf /tmp/autoconf.tar.gz -C /tmp
  install_pkg /tmp/autoconf-2.59
}

add_icu() {
  curl -o /tmp/icu.tgz -sL https://github.com/unicode-org/icu/releases/download/release-52-2/icu4c-52_2-src.tgz
  tar -xzf /tmp/icu.tgz -C /tmp
  install_pkg /tmp/icu/source
}

add_bison() {
  curl -o /tmp/bison.tar.gz -sL https://ftp.gnu.org/gnu/bison/bison-1.75.tar.gz
  tar -xzf /tmp/bison.tar.gz -C /tmp
  install_pkg /tmp/bison-1.75
}

add_openssl() {
  curl -o /tmp/openssl.tar.gz -sL https://www.openssl.org/source/openssl-1.0.2u.tar.gz
  tar -xzf /tmp/openssl.tar.gz -C /tmp
  (
    cd /tmp/openssl-1.0.2u || exit 1
    ./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib/openssl-1.0 shared zlib-dynamic
    make depend
    sudo make -j"$(nproc)"
    sudo make install INSTALL_PREFIX="$DESTDIR"
  )
}

mode="${1:-all}"
DESTDIR="${2:-}"

packages=(autoconf icu bison openssl)
if [ "$mode" = "all" ]; then
  for package in "${packages[@]}"; do
    add_"${package}"
  done
else
  add_"${mode}"
fi
