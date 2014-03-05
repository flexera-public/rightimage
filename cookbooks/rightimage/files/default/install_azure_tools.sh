#!/bin/bash -ex 

if [ -z "$BASE_URL" ]; then
  echo "BASE_URL not set!"
  exit 1
fi

cd /tmp

case "$PLATFORM" in
ubuntu*)
  apt-get -y install libev-dev libev4 libssl-dev libssl1.0.0  rlwrap
  packages="nodejs_0.8.26-1chl1~precise1_amd64.deb nodejs-dev_0.8.26-1chl1~precise1_amd64.deb npm_1.3.0-1chl1~precise1_all.deb"
  for pkg in $packages; do
    wget -q ${BASE_URL}/packages/ubuntu/$pkg
  done
  dpkg -i $packages
  ;;
rhel*|redhat*|centos*)
  # Replacepkgs ensures we don't error on rerun
  rpm -Uvh --replacepkgs ${BASE_URL}/packages/el6/nodejs-0.8.16-1.x86_64.rpm
  ;;
*)
  echo "ERROR: PLATFORM not set!"
  exit 1
  ;;
esac

# Use precompiled node_modules
# To generate the tarball cd to / then something like
# tar zcf azurecli-0.7.4.tar.gz /usr/lib/node_modules /usr/bin/azure
cd /tmp
wget -q ${BASE_URL}/files/azurecli-0.7.4.tar.gz
cd /
tar zxf /tmp/azurecli-0.7.4.tar.gz
