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

source_image = node[:rightimage][:mount_dir]

build_root = "/mnt"

guest_root = "#{build_root}/#{node[:rightimage][:cloud]}"

package_root = "#{build_root}/pkg"
cloud_package_root = "#{package_root}/#{node[:rightimage][:cloud]}"

bash "unmount proc & dev" do 
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    umount -lf $GUEST_ROOT/proc || true
#    umount -lf $GUEST_ROOT/dev || true
    umount -lf $GUEST_ROOT/sys || true
  EOH
end

bash "cleanup" do
  code <<-EOH
    set -x
    rm -rf #{guest_root}
    mkdir #{guest_root}
    rsync -a #{source_image}/ #{guest_root}/
  EOH
end

execute "echo -n #{node[:rightimage][:cloud]} > #{guest_root}/etc/rightscale.d/cloud" do 
  creates "#{guest_root}/etc/rightscale.d/cloud"
end

#  - add fstab
template "#{guest_root}/etc/fstab" do 
  source "fstab.erb" 
  backup false
end

bash "mount proc & dev" do 
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    mount -t proc none $GUEST_ROOT/proc
#    mount --bind /dev $GUEST_ROOT/dev
    mount --bind /sys $GUEST_ROOT/sys
  EOH
end

rightimage_kernel "xen" do
  guest_root guest_root 
  action :install
end

template "#{guest_root}/boot/grub/menu.lst" do
  source "menu.lst.erb"
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
  code <<-EOH
#!/bin/bash -ex
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
  code <<-EOH
#!/bin/bash -ex
  for module_version in $(cd #{guest_root}/lib/modules; ls); do
    chroot #{guest_root} depmod -a $module_version
  done
  EOH
end if node[:rightimage][:platform] == "centos"

#  - configure mirrors
template "#{guest_root}/#{node[:rightimage][:mirror_file_path]}" do 
  source node[:rightimage][:mirror_file] 
  backup false
end unless node[:rightimage][:platform] == "centos"

bash "unmount proc & dev" do 
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    umount -lf $GUEST_ROOT/proc || true
#    umount -lf $GUEST_ROOT/dev || true
    umount -lf $GUEST_ROOT/sys || true
  EOH
end

# Clean up GUEST_ROOT image
rightimage guest_root do
  action :sanitize
end

bash "sync fs" do 
  code <<-EOH
    set -x
    sync
  EOH
end
