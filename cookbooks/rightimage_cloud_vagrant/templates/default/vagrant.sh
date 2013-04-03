# Vagrant specific
date > /etc/vagrant_box_build_time

# Add vagrant user
set +e
/usr/sbin/groupadd vagrant
/usr/sbin/useradd vagrant -g vagrant -m -s /bin/bash
echo "vagrant:vagrant" | chpasswd

# Ensure includedir set
grep "includedir" /etc/sudoers
if [ $? == 1 ]; then
  echo "#includedir /etc/sudoers.d" >> /etc/sudoers
fi

set -e
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" > /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

# Installing vagrant keys
mkdir -pm 700 /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh
