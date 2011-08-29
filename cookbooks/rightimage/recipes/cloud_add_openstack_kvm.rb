class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

source_image = node[:rightimage][:mount_dir] 

build_root = "/mnt"

target_type = "#{node[:rightimage][:cloud]}_#{node[:rightimage][:virtual_environment]}"
target_raw = "#{target_type}.raw"
target_raw_path = "#{build_root}/#{target_raw}"
guest_root = "#{build_root}/#{target_type}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"
package "grub"

bash "create openstack-kvm loopback fs" do
  code <<-EOH
    set -e 
    set -x
  
    DISK_SIZE_GB=10  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    GUEST_ROOT="#{guest_root}"
    source_image="#{source_image}" 
    target_raw_path="#{target_raw_path}"

    umount -lf $source_image/proc || true 
    umount -lf $GUEST_ROOT/proc || true 
    umount -lf $GUEST_ROOT/sys || true 
    umount -lf $GUEST_ROOT || true
    rm -rf $target_raw_path $GUEST_ROOT
    
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
    mkdir $GUEST_ROOT
    mount $loopmap $GUEST_ROOT
    
    rsync -a $source_image/ $GUEST_ROOT/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    mount -t proc none $GUEST_ROOT/proc
    mount --bind /dev $GUEST_ROOT/dev
    mount --bind /sys $GUEST_ROOT/sys
  EOH
end

bash "install grub" do
  code <<-EOH
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    yum -c /tmp/yum.conf --installroot=$GUEST_ROOT -y install grub
  EOH
end

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x
    
    target_raw_path="#{target_raw_path}"
    GUEST_ROOT="#{guest_root}"
    
    chroot $GUEST_ROOT mkdir -p /boot/grub
    chroot $GUEST_ROOT cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
    chroot $GUEST_ROOT ln -s /boot/grub/grub.conf /boot/grub/menu.lst
    
    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $GUEST_ROOT/boot/grub/device.map
    echo "" >> $GUEST_ROOT/boot/grub/device.map

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

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  guest_root guest_root
  version node[:rightimage][:kernel_id]
  action :install
end


bash "configure for openstack" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$GUEST_ROOT -y clean all

    # enable console access
    #echo "2:2345:respawn:/sbin/mingetty tty2" >> $GUEST_ROOT/etc/inittab
    #echo "tty2" >> $GUEST_ROOT/etc/securetty

    # configure dns timeout 
    echo 'timeout 300;' > $GUEST_ROOT/etc/dhclient.conf

    mkdir -p $GUEST_ROOT/etc/rightscale.d
    echo "openstack" > $GUEST_ROOT/etc/rightscale.d/cloud

    rm ${GUEST_ROOT}/var/lib/rpm/__*
    chroot $GUEST_ROOT rpm --rebuilddb
    
    # set hwclock to UTC
    echo "UTC" >> $GUEST_ROOT/etc/adjtime

  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    GUEST_ROOT=#{guest_root}
    umount -lf $GUEST_ROOT/proc
    umount -lf $GUEST_ROOT/dev
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
    GUEST_ROOT=#{guest_root}
    loopdev=#{loop_dev}
    loopmap=#{loop_map}
    
    umount -lf $loopmap
    kpartx -d $loopdev
    losetup -d $loopdev
  EOH
end


bash "backup raw image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    cp -v $raw_image $raw_image.bak 
  EOH
end

bash "package image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    
    BUNDLED_IMAGE="#{image_name}.qcow2"
    BUNDLED_IMAGE_PATH="/mnt/$BUNDLED_IMAGE"
    
    qemu-img convert -O qcow2 #{target_raw_path} $BUNDLED_IMAGE_PATH
    bzip2 $BUNDLED_IMAGE_PATH

  EOH
end


