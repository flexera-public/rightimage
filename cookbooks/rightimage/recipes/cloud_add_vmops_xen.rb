class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

cloud = node[:rightimage][:cloud]
hypervisor = node[:rightimage][:virtual_environment]


raise "ERROR: you must set your cloud to vmops!"  if cloud != "vmops"
raise "ERROR: you must set your virtual_environment to xen!"  if hypervisor != "xen"

include_recipe "rightimage::install_vhd-util" if hypervisor == "xen"  


source_image = node[:rightimage][:mount_dir] 

target_root = "/mnt"
target_raw = "#{cloud}-#{hypervisor}.img"
target_raw_path = "#{target_root}/#{target_raw}"

guest_root = "#{target_root}/#{cloud}"

bash "create_vmops_image" do 
  code <<-EOH
    set -e 
    set -x

    source_image="#{source_image}" 
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{guest_root}/proc || true 
    umount -lf #{guest_root}/sys || true 
    umount -lf #{guest_root} || true

    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]}  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    rm -rf $target_raw_path $guest_root
    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    mke2fs -F -j $target_raw_path
    mkdir $guest_root
    mount -o loop $target_raw_path $guest_root
    rsync -a $source_image/ $guest_root/
    mkdir -p $guest_root/boot/grub

  EOH
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end


# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

bash "mount proc" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    mount_dir=#{guest_root}
    mount -t proc none $mount_dir/proc
  EOH
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{hypervisor}"
  guest_root guest_root
  version node[:rightimage][:kernel_id]
  action :install
end

bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    mount_dir=#{guest_root}

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
    target_mnt=#{guest_root}
    umount -lf $target_mnt/proc || true
  EOH
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{guest_root}    
    umount -lf $target_mnt
  EOH
end

bash "backup raw image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    cp -v $raw_image $raw_image.bak 
  EOH
end

bash "xen convert" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    raw_image=$(basename #{target_raw_path})
    vhd_image=${raw_image}.vhd
    vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
    vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
    bzip2 #{image_name}.vhd
  EOH
end

