class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# configure an image for a particular cloud. 
# we need to:
#  - configure ssh settings (do we want to disable passwd based root access for vmops?)
#  - insert proper init scripts (rackspace needs lvm hack)

# TODO: add uuca tools for centos 
#  - create /etc/rightscale.d/cloud
execute "echo -n #{node[:rightimage][:cloud]} > #{node[:rightimage][:mount_dir]}/etc/rightscale.d/cloud" do 
  creates "#{node[:rightimage][:mount_dir]}/etc/rightscale.d/cloud"
end


#  - add fstab
template "#{node[:rightimage][:mount_dir]}/etc/fstab" do 
  source "fstab.erb" 
  backup false
end

#  - add get_ssh_key script
template "#{node[:rightimage][:mount_dir]}/etc/init.d/getsshkey" do 
  source "getsshkey.erb" 
  mode "0544"
  backup false
end

execute "link_getsshkey" do 
  command  node[:rightimage][:getsshkey_cmd] 
end


#  - add cloud tools
bash "install_ec2_tools" do 
  creates "#{node[:rightimage][:mount_dir]}/home/ec2/bin"
  code <<-EOH
#!/bin/bash -ex
    ROOT=#{node[:rightimage][:mount_dir]}
    rm -rf #{node[:rightimage][:mount_dir]}/home/ec2 || true
    mkdir -p #{node[:rightimage][:mount_dir]}/home/ec2
    curl -o #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
    curl -o #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
    unzip #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools.zip -d #{node[:rightimage][:mount_dir]}/tmp/
    unzip #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools.zip -d #{node[:rightimage][:mount_dir]}/tmp/
    cp -r #{node[:rightimage][:mount_dir]}/tmp/ec2-api-tools-*/* #{node[:rightimage][:mount_dir]}/home/ec2/.
    rsync -av #{node[:rightimage][:mount_dir]}/tmp/ec2-ami-tools-*/ #{node[:rightimage][:mount_dir]}/home/ec2
    rm -r #{node[:rightimage][:mount_dir]}/tmp/ec2-a*
    echo 'export PATH=$PATH:/home/ec2/bin' >> #{node[:rightimage][:mount_dir]}/etc/profile.d/ec2.sh
    echo 'export EC2_HOME=/home/ec2' >> #{node[:rightimage][:mount_dir]}/etc/profile.d/ec2.sh
  EOH
end if node[:rightimage][:cloud] == "ec2"

package "euca2ools" if node[:rightimage][:cloud] == "eucalyptus" && node[:rightimage][:platform] == "ubuntu" 



#  - insert kernel mods (for centos)
bash "insert_kernel_mods" do 
  code <<-EOH
#!/bin/bash -ex
set -e
set -x
    echo "installing kernel modules..."
    if [ "#{node[:rightimage][:arch]}" == "i386" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/linux-2.6.16-ec2.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/usr/src/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/lib/modules/
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-i686.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-i686.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
    elif [ "#{node[:rightimage][:arch]}" == "x86_64" ]; then
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.16.33-xenU-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/rightscale_scripts/kernel-modules.2.6.16-xenU.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/lib/modules
      curl -s http://ec2-downloads.s3.amazonaws.com/ec2-modules-2.6.18-xenU-ec2-v1.0-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
      curl -s http://s3.amazonaws.com/ec2-downloads/ec2-modules-2.6.21-2952.fc8xen-x86_64.tgz | tar -xzC #{node[:rightimage][:mount_dir]}/
    else
      echo >&2 "architecture is not set properly: #{node[:rightimage][:arch]}"
      echo >&2 "exiting..."
      exit 2
    fi
    mv #{node[:rightimage][:mount_dir]}/lib/modules/2.6.21-2952.fc8xen #{node[:rightimage][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen
  EOH
end if node[:rightimage][:platform] == "centos"

# drop in amazon's recompiled xfs module 
#remote_file "#{node[:rightimage][:mount_dir]}/lib/modules/2.6.21.7-2.fc8xen/kernel/fs/xfs/xfs.ko" do 
  #source "xfs.ko.#{node[:rightimage][:arch]}"
  #backup false
#end if node[:rightimage][:platform] == "centos"

bash "do_depmod" do 
  code <<-EOH
#!/bin/bash -ex
  for module_version in $(cd #{node[:rightimage][:mount_dir]}/lib/modules; ls); do
    chroot #{node[:rightimage][:mount_dir]} depmod -a $module_version
  done

  EOH
end if node[:rightimage][:platform] == "centos"


#  - configure mirrors
template "#{node[:rightimage][:mount_dir]}#{node[:rightimage][:mirror_file_path]}" do 
  source node[:rightimage][:mirror_file] 
  backup false
end unless node[:rightimage][:platform] == "centos"

include_recipe "rightimage::ec2_ebs_bundle"
include_recipe "rightimage::ec2_s3_bundle"
include_recipe "rightimage::do_tag_images"

