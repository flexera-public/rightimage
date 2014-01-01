# Requirement of gem
if [ `lsb_release -is` == "Ubuntu" ]; then
  apt-get -y install rubygems ruby ruby-dev
else
  yum -y install rubygems ruby ruby-devel
fi

# Requirement of chef
# mime-types 2.0 requires ruby > 1.9.2
gem install --no-ri --no-rdoc mime-types -v "< 2.0"
# Install Chef
gem install --no-ri --no-rdoc chef -v 10.24.0
