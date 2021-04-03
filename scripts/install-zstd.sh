if command -v brew >/dev/null; then
  export PATH="$HOME/.linuxbrew/bin:$PATH"
  echo "export PATH=$HOME/.linuxbrew/bin:\$PATH" >> "$GITHUB_ENV"
  brew install zstd >/dev/null 2>&1
else
  curl -sSLO http://archive.ubuntu.com/ubuntu/pool/main/g/gcc-10/gcc-10-base_10-20200411-0ubuntu1_amd64.deb
  curl -sSLO http://archive.ubuntu.com/ubuntu/pool/main/g/gcc-10/libgcc-s1_10-20200411-0ubuntu1_amd64.deb
  curl -sSLO http://archive.ubuntu.com/ubuntu/pool/universe/libz/libzstd/zstd_1.4.4+dfsg-3_amd64.deb
  sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts ./*.deb && rm -rf ./*.deb
fi
zstd -V