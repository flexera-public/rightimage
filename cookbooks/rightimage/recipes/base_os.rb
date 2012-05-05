rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Most of the heavy lifting, install the os from scratch
rightimage_os node[:rightimage][:platform] do
  platform_version node[:rightimage][:platform_version].to_f
  arch node[:rightimage][:arch]
  action :install
end

# Common base image configurations 
bash "resolv.conf" do
  code <<-EOH
    echo "nameserver 8.8.4.4" >> #{guest_root}/etc/resolv.conf
  EOH
end

template "#{guest_root}/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  variables({
    :permit_root_login => "without-password",
    :password_authentication => "no"
  })
end

bash "install_rubygems" do 
  not_if  "chroot #{guest_root} which gem"
  flags "-ex"
  code <<-EOC
ROOT=#{guest_root}

function get_rubygems {
  wget -O $ROOT/tmp/rubygems.tgz $2 
  tar -xzvf $ROOT/tmp/rubygems.tgz  -C $ROOT/tmp
  mv $ROOT/tmp/rubygems-$1 $ROOT/tmp/rubygems
}

ruby_ver=`chroot $ROOT ruby --version`
if [[ $ruby_ver == *1.8.5* ]] ; then
  get_rubygems 1.3.3 http://rubyforge.org/frs/download.php/56227/rubygems-1.3.3.tgz
  # Newer versions of rake will not work with older versions of Ruby
  rake_ver="-v 0.9.2";
else
  get_rubygems 1.3.7 http://rubyforge.org/frs/download.php/70696/rubygems-1.3.7.tgz
  rake_ver="";
fi

cat <<-CHROOT_SCRIPT > $ROOT/tmp/rubygems_install.sh
#!/bin/bash -ex
cd /tmp/rubygems
ruby setup.rb 
if [ "#{node[:rightimage][:platform]}" == "ubuntu" ]; then
  ln -sf /usr/bin/gem1.8 /usr/bin/gem
fi

gem install xml-simple net-ssh net-sftp  --no-ri --no-rdoc
gem install rake $rake_ver --no-ri --no-rdoc
updatedb
CHROOT_SCRIPT
chmod +x $ROOT/tmp/rubygems_install.sh
chroot $ROOT /tmp/rubygems_install.sh > /dev/null 
EOC
end

# Clean up GUEST_ROOT image
rightimage guest_root do
  action :sanitize
end

rightscale_marker :end
