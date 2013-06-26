rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource
  include RightScale::RightImage::Helper
end

bash "insert_bashrc" do 
  # note that ubuntu uses /etc/bash.bashrc and sources it automatically for us
  # also note that .bashrc in /skel already has this code so it should work 
  # normally for rightlink created users
  flags "+e -x"
  code <<-EOS
    grep ". /etc/bashrc" #{guest_root}/root/.bashrc
    if [ "$?" == "2" -o "$?" == "1" ]; then
cat <<-BASHRC >> #{guest_root}/root/.bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
BASHRC
    fi
  EOS
end

# Ubuntu only, centos sources /etc/profile.d as it should
bash "set ec2 home var for all users" do 
  only_if { node[:rightimage][:platform] == "ubuntu" && node[:rightimage][:cloud] == "ec2" }
  flags "+e -x"
  code <<-EOS
    grep "EC2_HOME" #{guest_root}/etc/bash.bashrc
    if [ "$?" == "1" ]; then
      mv -f #{guest_root}/etc/bash.bashrc /tmp/bash.save
      echo 'export PATH=$PATH:/home/ec2/bin' > #{guest_root}/etc/bash.bashrc
      echo 'export EC2_HOME=/home/ec2' >> #{guest_root}/etc/bash.bashrc
      cat /tmp/bash.save >> #{guest_root}/etc/bash.bashrc
    fi
  EOS
end

include_recipe "rightimage::rightscale_rightlink"

rightimage guest_root do
  action :sanitize
end

rightscale_marker :end
