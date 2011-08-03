class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"
package "grub"

bash "create cloudstack-kvm loopback fs" do 
  code <<-EOH
    set -e 
    set -x
  
    DISK_SIZE_GB=10  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    source_image="#{node.rightimage.mount_dir}" 
    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{target_mnt}/proc || true 
    umount -lf #{target_mnt} || true
    rm -rf $target_raw_path $target_mnt
    
    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    
    loopdev=#{loop_dev}
    loopmap=#{loop_map}

    set +e    
    [ -e "/dev/mapper/#{loop_name}p1" ] && kpartx -d #{loop_dev}
    losetup -a | grep #{loop_dev}
    [ "$?" == "0" ] && losetup -d #{loop_dev}
    set -e
    losetup $loopdev $target_raw_path
    
    sfdisk $loopdev << EOF
0,1304,L
EOF
    
    kpartx -a $loopdev
    mke2fs -F -j $loopmap
    mkdir $target_mnt
    mount $loopmap $target_mnt
    
    rsync -a $source_image/ $target_mnt/

  EOH
end

bash "mount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    mount -t proc none $target_mnt/proc
    mount --bind /dev $target_mnt/dev
  EOH
end

bash "install grub" do
  code <<-EOH
    set -e 
    set -x
    target_mnt="#{target_mnt}"
    yum -c /tmp/yum.conf --installroot=$target_mnt -y install grub
  EOH
end

# add fstab
template "#{target_mnt}/etc/fstab" do
  source "fstab.erb"
  backup false
end

# insert grub conf
template "#{target_mnt}/boot/grub/grub.conf" do 
  source "grub.conf"
  backup false 
end

bash "setup grub" do 
  code <<-EOH
    set -e 
    set -x
    
    target_raw_path="#{target_raw_path}"
    target_mnt="#{target_mnt}"
    
    chroot $target_mnt mkdir -p /boot/grub

    if [ "#{node.rightimage.platform}" == "centos" ]; then 
      chroot $target_mnt cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
    fi

    chroot $target_mnt ln -sf /boot/grub/grub.conf /boot/grub/menu.lst
    
    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $target_mnt/boot/grub/device.map
    echo "" >> $target_mnt/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF

    if [ "#{node.rightimage.platform}" == "ubuntu" ]; then
      sbin_command="/usr/sbin/grub"
    else
      sbin_command="/sbin/grub"
    fi

    ${sbin_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 
    
  EOH
end

bash "install kvm kernel" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}


  case "#{node.rightimage.platform}" in 
    "centos" )
      # The following should be needed when using ubuntu vmbuilder
      yum -c /tmp/yum.conf --installroot=$target_mnt -y install kmod-kvm
      rm -f $target_mnt/boot/initrd*
      chroot $target_mnt mkinitrd --with=ata_piix --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
      mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
      ;;
    "ubuntu" )
      # Anything need to be done?
      ;;
  esac
      
  EOH
end

bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

    case "#{node.rightimage.platform}" in
    "centos")

      # clean out packages
      yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all

      # clean centos RPM data
      rm ${target_mnt}/var/lib/rpm/__*
      chroot $target_mnt rpm --rebuilddb

      # enable console access
      echo "2:2345:respawn:/sbin/mingetty tty2" >> $target_mnt/etc/inittab
      echo "tty2" >> $target_mnt/etc/securetty

      # configure dns timeout 
      echo 'timeout 300;' > $target_mnt/etc/dhclient.conf
      ;;

    "ubuntu")
      # More to do for Ubuntu?
      echo 'timeout 300;' > $target_mnt/etc/dhcp3/dhclient.conf      
      ;;
    esac

    mkdir -p $target_mnt/etc/rightscale.d
    echo "vmops" > $target_mnt/etc/rightscale.d/cloud

    rm ${target_mnt}/var/lib/rpm/__*
    chroot $target_mnt rpm --rebuilddb
    
    # set hwclock to UTC
    echo "UTC" >> $target_mnt/etc/adjtime

  EOH
end

bash "unmount proc & dev" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    umount -lf $target_mnt/proc
    umount -lf $target_mnt/dev
  EOH
end

# Clean up guest image
rightimage target_mnt do
  action :sanitize
end

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
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


