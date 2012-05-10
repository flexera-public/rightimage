rs_utils_marker :begin
class Chef::Resource::Bash
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

raise "ERROR: you must set your virtual_environment to xen!"  if node[:rightimage][:virtual_environment] != "xen"

euca_tools_version = "1.3.1"

bash "clean yum" do
  only_if { node[:platform] == "centos" }
  flags "-x"
  code <<-EOH
    yum clean all
  EOH
end

package "grub"

#  - add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

remote_file "/tmp/euca2ools-#{euca_tools_version}-centos-i386.tar.gz" do 
  source "euca2ools-#{euca_tools_version}-centos-i386.tar.gz"
  backup false
end

remote_file "/tmp/euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz" do 
  source "euca2ools-#{euca_tools_version}-centos-x86_64.tar.gz"
  backup false
end

bash "mount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  guest_root guest_root
  version node[:rightimage][:kernel_id]
  action :install
end

include_recipe "rightimage::bootstrap_common_debug"

package "euca2ools" do
  only_if { node[:rightimage][:platform] == "ubuntu" }
end

bash "install euca tools for centos" do 
  only_if { node[:rightimage][:platform] == "centos" }
  flags "-ex"
  code <<-EOH
    VERSION=#{euca_tools_version}  
    guest_root=#{guest_root}
      
    # install on host
    cd /tmp
    export ARCH=#{node[:kernel][:machine]}
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz 
    cd  euca2ools-$VERSION-centos-$ARCH
    rpm -i --force * 

    # install on guest_root image
    cd $guest_root/tmp/.
    export ARCH=#{node[:rightimage][:arch]}
    cp /tmp/euca2ools-$VERSION-centos-$ARCH.tar.gz $guest_root/tmp/.
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz
    chroot $guest_root rpm -i --force /tmp/euca2ools-$VERSION-centos-$ARCH/*
    
  EOH
end

bash "configure for eucalyptus" do
  only_if { node[:platform] == "centos" }
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}

    ## insert cloud file
    mkdir -p $guest_root/etc/rightscale.d
    echo -n "eucalyptus" > $guest_root/etc/rightscale.d/cloud

    # clean out packages
    chroot $guest_root yum -y clean all
    
    rm ${guest_root}/var/lib/rpm/__*
    chroot $guest_root rpm --rebuilddb

  EOH
end

execute "sync"

bash "unmount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc || true
    umount -lf $guest_root/dev || true
    umount -lf $guest_root/sys || true
  EOH
end

# Clean up guest_root image
rightimage guest_root do
  action :sanitize
end

bash "package guest image" do 
  cwd "/mnt"
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    image_name=#{image_name}
    cloud_package_root=#{target_temp_root}
    package_dir=$cloud_package_root/$image_name
    KERNEL_VERSION=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
    INITRD=#{node[:rightimage][:platform] == "ubuntu" ? "initrd.img" : "initrd"}

    rm -rf $package_dir
    mkdir -p $package_dir
    cd $cloud_package_root
    mkdir $package_dir/xen-kernel
    cp $guest_root/boot/vmlinuz-$KERNEL_VERSION $package_dir/xen-kernel
    cp $guest_root/boot/$INITRD-$KERNEL_VERSION $package_dir/xen-kernel
    cp #{target_raw_path} $package_dir/$image_name.img
    tar czvf $image_name.tar.gz $image_name 
  EOH
end

bash "unmount" do
  flags "-x"
  code <<-EOH
    guest_root=#{guest_root}
    loopdev=#{loop_dev}  
    umount -lf $guest_root || true
    losetup -d $loopdev
  EOH
end
rs_utils_marker :end
