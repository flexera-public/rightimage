class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to xen!"  if node[:rightimage][:virtual_environment] != "xen"

include_recipe "rightimage::install_vhd-util" if node[:rightimage][:virtual_environment] == "xen"  

source_image = node[:rightimage][:mount_dir] 
destination_image = "/mnt/vmops_image"
destination_image_mount = "/mnt/vmops_image_mount"
vhd_image = destination_image + '.vhd'

bash "create_vmops_image" do 
  code <<-EOH
    set -e 
    set -x

    source_image="#{source_image}" 
    destination_image="#{destination_image}"
    destination_image_mount="#{destination_image_mount}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{destination_image_mount}/proc || true 
    umount -lf #{destination_image_mount}/sys || true 
    umount -lf #{destination_image_mount} || true

    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]}  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    rm -rf $destination_image $destination_image_mount
    dd if=/dev/zero of=$destination_image bs=1M count=$DISK_SIZE_MB    
    mke2fs -F -j $destination_image
    mkdir $destination_image_mount
    mount -o loop $destination_image $destination_image_mount
    rsync -a $source_image/ $destination_image_mount/
    mkdir -p $destination_image_mount/boot/grub

  EOH
end

# insert grub conf
template "#{destination_image_mount}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end


# add fstab
template "#{destination_image_mount}/etc/fstab" do
  source "fstab.erb"
  backup false
end

bash "mount proc" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    mount_dir=#{destination_image_mount}
    mount -t proc none $mount_dir/proc
  EOH
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  guest_root guest_root
  version node[:rightimage][:kernel_id]
  action :install
end

bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    mount_dir=#{destination_image_mount}

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$mount_dir -y clean all

    # enable console access
    echo "2:2345:respawn:/sbin/mingetty xvc0" >> $mount_dir/etc/inittab
    echo "xvc0" >> $mount_dir/etc/securetty

    # configure dns timeout 
    echo 'timeout 300;' > $mount_dir/etc/dhclient.conf

    mkdir -p $mount_dir/etc/rightscale.d
    echo "cloudstack" > $mount_dir/etc/rightscale.d/cloud

    rm ${mount_dir}/var/lib/rpm/__*
    chroot $mount_dir rpm --rebuilddb
  EOH
end

bash "unmount proc" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{destination_image_mount}
    umount -lf $target_mnt/proc || true
  EOH
end

# Clean up guest image
rightimage destination_image_mount do
  action :sanitize
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{destination_image_mount}    
    umount -lf $target_mnt
  EOH
end

bash "backup raw image" do 
  cwd File.dirname destination_image
  code <<-EOH
    raw_image=$(basename #{destination_image})
    cp -v $raw_image $raw_image.bak 
  EOH
end

bash "xen convert" do 
  cwd File.dirname destination_image
  code <<-EOH
    set -e
    set -x
    raw_image=$(basename #{destination_image})
    vhd_image=${raw_image}.vhd
    vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
    vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
    bzip2 #{image_name}.vhd
  EOH
end

