#!/bin/bash -ex

if [ -z "$BASE_URL" ]; then
  echo "BASE_URL not set!"
  exit 1
fi

if [ ! -e /bin/real-uname ]; then
  mv /bin/uname /bin/real-uname
  mv /tmp/fake-uname /bin/uname
fi


kernel_version=$(ls -t /lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
if which apt-get; then
  apt-get install -y dkms linux-headers-$kernel_version gcc make
  if apt-cache show fuse-utils; then 
    apt-get install -y fuse-utils
  else
    apt-get install -y fuse
  fi
else
  for pkg in dkms gcc make fuse fuse-libs; do
    yum install -y $pkg
  done
  headers="kernel-headers"
  # kernel-plus-headers conflicts with kernel-headers package, so install the right one
  # Need to install after dkms since it installs kernel headers
  rpm -qa "kernel-plus-headers" | grep "^kernel" && headers="kernel-plus-headers"
  yum install -y $headers
fi

cd /tmp
if [ ! -e /tmp/vmware-tools-distrib ]; then 
  curl --silent --fail $BASE_URL/files/VMwareTools-9.4.0-1280544.gz -o /tmp/vmware-tools-distrib.tar.gz
  tar zxpf vmware-tools-distrib.tar.gz
fi
cd /tmp/vmware-tools-distrib

# this part is kinda hacky -- vmware-install runs vmware-config-tools automatically
# for us but it fails (without setting the return code properly) since vmware-checkvm
# says we're not in a vm.  We just go and ahead and add a dummy checkvm command
# 
output=$(./vmware-install.pl --default 2>&1)

# vmware-install always lays down
mv /usr/lib/vmware-tools/sbin64/vmware-checkvm /bin/real-vmware-checkvm
mv /tmp/fake-vmware-checkvm /usr/lib/vmware-tools/sbin64/vmware-checkvm

/usr/bin/vmware-config-tools.pl --default --skip-stop-start

# Reinstall VMware tools on boot when the kernel is updated (IV-773)
# Sed this after running config, or it doesn't save the setting
#
# Known limitation: user needs to update/install kernel headers so the VMware
#  modules can be rebuilt. CentOS: kernel-devel, Ubuntu: linux-headers
sed -i "s/answer AUTO_KMODS_ENABLED_ANSWER no/answer AUTO_KMODS_ENABLED_ANSWER yes/" /etc/vmware-tools/locations
sed -i "s/answer AUTO_KMODS_ENABLED no/answer AUTO_KMODS_ENABLED yes/" /etc/vmware-tools/locations

# We depmod against the host kernel by default - force guest depmod. We also
# throw lots of FATAL type errors in vmware-config-tools but that's ok, they're
# not actually fatal
depmod -a `uname -r`

mv /bin/real-uname /bin/uname
mv /bin/real-vmware-checkvm /usr/lib/vmware-tools/sbin64/vmware-checkvm
