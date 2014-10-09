# Install Puppet
apt-get -y install puppet facter
service puppet stop
rm -f /var/lib/puppet/ssl/private_keys/*
