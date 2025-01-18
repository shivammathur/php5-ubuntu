. /etc/os-release
debconf_fix="DEBIAN_FRONTEND=noninteractive"
dpkg_install="sudo $debconf_fix dpkg -i --force-conflicts --force-overwrite"
sudo mkdir -p /var/run /run/php /usr/local/php /usr/lib/systemd/system /usr/lib/cgi-bin /var/www/html
arch="$(arch)"
if [[ "$arch" = "arm64" || "$arch" = "aarch64" ]]; then
  arch="arm64";
  arch_name="-arm64";
else
  arch="amd64"
  arch_name=""
fi
[[ "$VERSION_ID" = "20.04" || "$VERSION_ID" = "22.04" || $VERSION_ID = "24.04" ]] && $dpkg_install ./deps/"$VERSION_ID"/multiarch-support_2.28-10_"$arch"
$dpkg_install ./deps/"$VERSION_ID"/*_"$arch".deb
$dpkg_install ./deps/all/*_"$arch".deb
sudo tar -I zstd -xf ./php-@PHP_VERSION@-build"$arch_name".tar.zst -C /usr/local/php
sudo ln -sf /usr/local/php/@PHP_VERSION@/etc/php.ini /etc/php.ini
