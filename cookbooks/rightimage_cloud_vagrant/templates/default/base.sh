# Base install

sed -i "s/requiretty//" /etc/sudoers
# kernel headers that match the host are required for guest additions to build the kernel modules
yum -y install dkms kernel-devel-`uname -r`
