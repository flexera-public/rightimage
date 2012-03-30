rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end
class Chef::Resource::Execute
  include RightScale::RightImage::Helper
end



# configure an image for a particular cloud. 
# we need to:
#  - configure ssh settings (do we want to disable passwd based root access for vmops?)
#  - insert proper init scripts (rackspace needs lvm hack)

# TODO: add uuca tools for centos 


include_recipe "cloud_add_begin"

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  action :install
end

#  - add get_ssh_key script
template "#{guest_root}/etc/init.d/getsshkey" do 
  source "getsshkey.erb" 
  mode "0544"
  backup false
end

execute "link_getsshkey" do 
  command  node[:rightimage][:getsshkey_cmd]
  environment ({'GUEST_ROOT' => guest_root }) 
end

#  - add cloud tools
bash "install_ec2_tools" do 
  creates "#{guest_root}/home/ec2/bin"
  flags "-ex"
  code <<-EOH
    ROOT=#{guest_root}
    rm -rf $ROOT/home/ec2 || true
    mkdir -p $ROOT/home/ec2
    curl -o $ROOT/tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    curl -o $ROOT/tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
    unzip $ROOT/tmp/ec2-api-tools.zip -d $ROOT/tmp/
    unzip $ROOT/tmp/ec2-ami-tools.zip -d $ROOT/tmp/
    cp -r $ROOT/tmp/ec2-api-tools-*/* $ROOT/home/ec2/.
    rsync -av $ROOT/tmp/ec2-ami-tools-*/ $ROOT/home/ec2
    rm -r $ROOT/tmp/ec2-a*
    echo 'export PATH=/home/ec2/bin:${PATH}' >> $ROOT/etc/profile.d/ec2.sh
    echo 'export EC2_HOME=/home/ec2' >> $ROOT/etc/profile.d/ec2.sh
    chroot $ROOT gem install s3sync --no-ri --no-rdoc
  EOH
end
 
bash "do_depmod" do 
  flags "-ex"
  only_if { node[:rightimage][:platform] == "centos" }
  code <<-EOH
  for module_version in $(cd #{guest_root}/lib/modules; ls); do
    chroot #{guest_root} depmod -a $module_version
  done
  EOH
end 

include_recipe "cloud_add_end"
