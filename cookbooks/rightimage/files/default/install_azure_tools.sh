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
  rpm -Uvh ${BASE_URL}/packages/el6/nodejs-0.8.16-1.x86_64.rpm
  ;;
*)
  echo "ERROR: PLATFORM not set!"
  exit 1
  ;;
esac

npm install -g azure-cli@0.7.4

# Remove .swp files
find /root/.npm /usr/lib/node* /usr/lib/node_modules -name *.swp -exec rm -rf {} \;
