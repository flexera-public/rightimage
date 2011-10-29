class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end


raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"
package "grub"

bash "create openstack-kvm loopback fs" do
  code <<-EOH
    set -e 
    set -x
  
    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]}
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    base_root="#{base_root}"
    guest_root="#{guest_root}"
    source_image="#{source_image}" 
    target_raw_root="#{target_raw_root}"
    target_raw_path="#{target_raw_path}"

    umount -lf $source_image/proc || true 
    umount -lf $guest_root/proc || true 
    umount -lf $guest_root/sys || true 
    umount -lf $guest_root || true
    rm -rf $base_root

    mkdir -p $target_raw_root
    
    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    
    loopdev=#{loop_dev}
    loopmap=#{loop_map}

    set +e    
    [ -e "$loopmap" ] && kpartx -d #{loop_dev}
    losetup -a | grep #{loop_dev}
    [ "$?" == "0" ] && losetup -d #{loop_dev}
    set -e
    losetup $loopdev $target_raw_path
    
    sfdisk $loopdev << EOF
0,1304,L
EOF
    
    kpartx -a $loopdev
    mke2fs -F -j $loopmap
    mkdir -p $guest_root
    mount $loopmap $guest_root
    
    rsync -a $source_image/ $guest_root/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
#  guest_root guest_root
#  version node[:rightimage][:kernel_id]
  action :install
end

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

bash "install grub" do
  code <<-EOH
    set -e 
    set -x
    guest_root=#{guest_root}
    yum -c /tmp/yum.conf --installroot=$guest_root -y install grub
  EOH
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "menu.lst.erb"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x
    
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"
    
    chroot $guest_root mkdir -p /boot/grub
    chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
    chroot $guest_root ln -s /boot/grub/grub.conf /boot/grub/menu.lst
    
    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $guest_root/boot/grub/device.map
    echo "" >> $guest_root/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF
    /sbin/grub --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 
    
  EOH
end

include_recipe "rightimage::bootstrap_common"

bash "configure for openstack" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$guest_root -y clean all

    # enable console access
    #echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
    #echo "tty2" >> $guest_root/etc/securetty

    # configure dns timeout 
    echo 'timeout 300;' > $guest_root/etc/dhclient.conf

    mkdir -p $guest_root/etc/rightscale.d
    echo "openstack" > $guest_root/etc/rightscale.d/cloud

    rm ${guest_root}/var/lib/rpm/__*
    chroot $guest_root rpm --rebuilddb
    
    # set hwclock to UTC
    echo "UTC" >> $guest_root/etc/adjtime

  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    umount -lf $guest_root/proc
    umount -lf $guest_root/dev
    umount -lf $guest_root/sys
  EOH
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

bash "sync fs" do 
  code <<-EOH
    set -x
    sync
  EOH
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}
    loopdev=#{loop_dev}
    loopmap=#{loop_map}
    
    umount -lf $loopmap
    kpartx -d $loopdev
    losetup -d $loopdev
  EOH
end


bash "backup raw image" do 
  cwd target_raw_root
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    cp -v $raw_image $raw_image.bak 
  EOH
end

bash "package image" do 
  cwd target_raw_root
  code <<-EOH
    set -e
    set -x
    
    BUNDLED_IMAGE="#{image_name}.qcow2"
    BUNDLED_IMAGE_PATH="#{target_raw_root}/$BUNDLED_IMAGE"
    
    qemu-img convert -O qcow2 #{target_raw_path} $BUNDLED_IMAGE_PATH
  EOH
end
