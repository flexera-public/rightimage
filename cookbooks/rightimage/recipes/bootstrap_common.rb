rs_utils_marker :begin
class Chef::Resource::Template
  include RightScale::RightImage::Helper
end
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Common base image configurations 
bash "resolv.conf" do
  code <<-EOH
    echo "nameserver 8.8.4.4" >> #{guest_root}/etc/resolv.conf
  EOH
end

template "#{guest_root}/etc/ssh/sshd_config" do
  source "sshd_config.erb"
  backup false
  variables({
    :permit_root_login => "without-password",
    :password_authentication => "no"
  })
end

bash "install_rubygems" do 
  not_if  "chroot #{node[:rightimage][:mount_dir]} which gem"
  flags "-ex"
  code <<-EOC
ROOT=#{node[:rightimage][:mount_dir]}

function get_rubygems {
  # Don't use wget -- Old versions have unreliable return codes (such as on CentOS 5)
  curl -o $ROOT/tmp/rubygems.tgz --fail --silent http://s3.amazonaws.com/rightscale_software/rubygems-$1.tgz
  tar -xzvf $ROOT/tmp/rubygems.tgz  -C $ROOT/tmp
  mv $ROOT/tmp/rubygems-$1 $ROOT/tmp/rubygems
}

ruby_ver=`chroot $ROOT ruby --version`
if [[ $ruby_ver == *1.8.5* ]] ; then
  get_rubygems 1.3.3
  # Newer versions of rake will not work with older versions of Ruby
  rake_ver="-v 0.9.2";
else
  get_rubygems 1.3.7
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

rs_utils_marker :end
