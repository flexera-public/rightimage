#!/bin/bash -ex
case "$PLATFORM" in
ubuntu*)
  apt-get -y install python-dev python-setuptools wget
  ;;
rhel*|redhat*|centos*)
  yum -y install python-setuptools python-devel python-libs wget
  ;;
*)
  echo "ERROR: PLATFORM not set!"
  exit 1
  ;;
esac

if [ -z "$BASE_URL" ]; then
  echo "BASE_URL not set!"
  exit 1
fi

# Install gcutil
cd /tmp
gcutil=gcutil-1.11.0
wget -q $BASE_URL/files/${gcutil}.tar.gz
tar zxf ${gcutil}.tar.gz -C /usr/local
rm -rf /usr/local/gcutil
mv /usr/local/${gcutil} /usr/local/gcutil
echo 'export PATH=$PATH:/usr/local/gcutil' > /etc/profile.d/gcutil.sh

# Install GSUtil
gsutil=gsutil-3.38
wget -q $BASE_URL/files/${gsutil}.tar.gz
tar zxf ${gsutil}.tar.gz -C /usr/local
echo 'export PATH=$PATH:/usr/local/gsutil' > /etc/profile.d/gsutil.sh
