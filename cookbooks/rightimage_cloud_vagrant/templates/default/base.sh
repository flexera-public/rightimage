# Base install

# Disable requiretty as documented in:
# http://docs-v1.vagrantup.com/v1/docs/base_boxes.html
sed -i "/^Defaults/ s/ requiretty/ \!requiretty/" /etc/sudoers
# kernel headers that match the host are required for guest additions to build the kernel modules
yum -y install dkms kernel-devel
