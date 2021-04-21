sudo mkdir -p /opt/zstd
. /etc/os-release
zstd_dir=$(curl -sL https://github.com/facebook/zstd/releases/latest | grep -Po "zstd-(\d+\.\d+\.\d+)" | head -n 1)
zstd_url=$(curl -sL https://api.github.com/repos/"$REPO"/actions/artifacts | jq -r --arg zstd_dir "$zstd_dir-ubuntu$VERSION_ID" '.artifacts[] | select(.name=="\($zstd_dir)").archive_download_url' 2>/dev/null | head -n 1)
if [ "x$zstd_url" = "x" ]; then
  sudo apt-get install zlib1g liblzma-dev liblz4-dev -y
  curl -o /tmp/zstd.tar.gz -sL https://github.com/facebook/zstd/releases/latest/download/"$zstd_dir".tar.gz
  tar -xzf /tmp/zstd.tar.gz -C /tmp
  (
    cd /tmp/"$zstd_dir" || exit 1
    sudo make install -j"$(nproc)" PREFIX=/opt/zstd
  )
else
  curl -u "$USER":"$GITHUB_TOKEN" -o /tmp/zstd.zip -sL "$zstd_url"
  ls /tmp
  sudo unzip /tmp/zstd.zip -d /opt/zstd
  sudo chmod -R a+x /opt/zstd/bin
fi
sudo ln -sf /opt/zstd/bin/* /usr/local/bin
sudo rm -rf /tmp/zstd*
zstd -V