# Base install

apt-get -y install sudo

# kernel headers that match the host are required for guest additions to build the kernel modules
apt-get -y install dkms linux-headers-`uname -r`
