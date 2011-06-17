class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to xen!"  if node[:rightimage][:virtual_environment] != "xen"

euca_tools_version = "1.3.1"

source_image = node[:rightimage][:mount_dir]

build_root = "/mnt"

target_raw = "eucalyptus.img"
target_raw_path = "#{build_root}/#{target_raw}"
guest_root = "#{build_root}/euca"

package_root = "#{build_root}/pkg"
cloud_package_root = "#{package_root}/euca"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"

package "grub"

bash "cleanup" do 
  code <<-EOH
    set -x
    GUEST_ROOT=#{guest_root}
    source_image="#{source_image}" 
    loopdev=#{loop_dev}  
    umount -lf $source_image/proc || true 
    umount -lf $GUEST_ROOT/proc || true 
    umount -lf $GUEST_ROOT/dev || true
    umount -lf $GUEST_ROOT || true
    losetup -d $loopdev
    rm -rf $target_raw_path $GUEST_ROOT
  EOH
end

bash "create eucalyptus loopback fs" do 
  code <<-EOH
    set -e 
    set -x
  
#    DISK_SIZE_GB=10  
    DISK_SIZE_GB=4  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    source_image="#{source_image}" 
    target_raw_path="#{target_raw_path}"
    GUEST_ROOT="#{guest_root}"
    
    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    
    loopdev=#{loop_dev}
    losetup $loopdev $target_raw_path
    
    mke2fs -F -j $loopdev
    mkdir $GUEST_ROOT
    mount $loopdev $GUEST_ROOT
    
    rsync -a $source_image/ $GUEST_ROOT/
  EOH
end

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
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    mount -t proc none $GUEST_ROOT/proc
    mount --bind /dev $GUEST_ROOT/dev
  EOH
end

rightimage_kernel "xen" do
  guest_root guest_root
  version node[:rightimage][:kernel_id]
  action :install
end

package "euca2ools" do
  only_if { node[:rightimage][:platform] == "ubuntu" }
end

bash "install euca tools for centos" do 
  only_if { node[:rightimage][:platform] == "centos" }
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    
    VERSION=#{euca_tools_version}  
    GUEST_ROOT=#{guest_root}
      
    # install on host
    cd /tmp
    export ARCH=#{node[:kernel][:machine]}
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz 
    cd  euca2ools-$VERSION-centos-$ARCH
    rpm -i --force * 

    # install on GUEST_ROOT image
    cd $GUEST_ROOT/tmp/.
    export ARCH=#{node[:rightimage][:arch]}
    cp /tmp/euca2ools-$VERSION-centos-$ARCH.tar.gz $GUEST_ROOT/tmp/.
    tar -xzvf euca2ools-$VERSION-centos-$ARCH.tar.gz
    chroot $GUEST_ROOT rpm -i --force /tmp/euca2ools-$VERSION-centos-$ARCH/*
    
  EOH
end

bash "configure for eucalyptus" do 
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}

    ## insert cloud file
    mkdir -p $GUEST_ROOT/etc/rightscale.d
    echo -n "eucalyptus" > $GUEST_ROOT/etc/rightscale.d/cloud

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$GUEST_ROOT -y clean all
    
    rm ${GUEST_ROOT}/var/lib/rpm/__*
    chroot $GUEST_ROOT rpm --rebuilddb

  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    umount -lf $GUEST_ROOT/proc
    umount -lf $GUEST_ROOT/dev
  EOH
end

# Clean up GUEST_ROOT image
rightimage guest_root do
  action :sanitize
end

bash "package guest image" do 
  cwd "/mnt"
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    image_name=#{image_name}
    cloud_package_root=#{cloud_package_root}
    package_dir=$cloud_package_root/$image_name
    rm -rf $package_dir
    mkdir -p $package_dir
    cd $cloud_package_root
    mkdir $package_dir/xen-kernel
    cp $GUEST_ROOT/boot/vmlinuz-2.6.18-164.15.1.el5.centos.plusxen $package_dir/xen-kernel
    cp $GUEST_ROOT/boot/initrd-2.6.18-164.15.1.el5.centos.plusxen $package_dir/xen-kernel
    cp #{target_raw_path} $package_dir/$image_name.img
    tar czvf $image_name.tar.gz $image_name 
  EOH
end

# bash "unmount" do 
#   code <<-EOH
#     set -x
#     GUEST_ROOT=#{guest_root}
#     loopdev=#{loop_dev}  
#     umount -lf $GUEST_ROOT || true
#     losetup -d $loopdev
#   EOH
# end

