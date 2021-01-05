curl -sSLO http://archive.ubuntu.com/ubuntu/pool/main/g/gcc-10/gcc-10-base_10-20200411-0ubuntu1_amd64.deb
curl -sSLO http://archive.ubuntu.com/ubuntu/pool/main/g/gcc-10/libgcc-s1_10-20200411-0ubuntu1_amd64.deb
curl -sSLO http://archive.ubuntu.com/ubuntu/pool/universe/libz/libzstd/zstd_1.4.4+dfsg-3_amd64.deb
sudo DEBIAN_FRONTEND=noninteractive dpkg -i --force-conflicts ./*.deb && rm -rf ./*.deb
zstd -V