class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

bundled_image = "cloustack-kvm.qcow2"
bundled_image_path = "/mnt/#{bundled_image}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

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
    chroot $target_mnt cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
    chroot $target_mnt ln -s /boot/grub/grub.conf /boot/grub/menu.lst
    
    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $target_mnt/boot/grub/device.map
    echo "" >> $target_mnt/boot/grub/device.map

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

bash "install kvm kernel" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    yum -c /tmp/yum.conf --installroot=$target_mnt -y install kmod-kvm
    rm -f $target_mnt/boot/initrd*
    chroot $target_mnt mkinitrd --with=ata_piix --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
    mv $target_mnt/initrd-#{node[:rightimage][:kernel_id]}  $target_mnt/boot/.
  EOH
end

bash "configure for cloudstack" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}

    # clean out packages
    yum -c /tmp/yum.conf --installroot=$target_mnt -y clean all

    # enable console access
    #echo "2:2345:respawn:/sbin/mingetty tty2" >> $target_mnt/etc/inittab
    #echo "tty2" >> $target_mnt/etc/securetty

    # configure dns timeout 
    echo 'timeout 300;' > $target_mnt/etc/dhclient.conf

    mkdir -p $target_mnt/etc/rightscale.d
    echo "vmops" > $target_mnt/etc/rightscale.d/cloud

    rm ${target_mnt}/var/lib/rpm/__*
    chroot $target_mnt rpm --rebuilddb

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

bash "unmount target filesystem" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    loopdev=#{loop_dev}
    loopmap=#{loop_map}
    
    umount -lf $loopmap
    kpartx -d $loopmap
#FIXME    losetup -d $loopdev
  EOH
end


bash "backup raw image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    cp -v $raw_image $raw_image.bak 
  EOH
end

# Clean up guest image
rightimage node[:rightimage][:mount_dir] do
  action :sanitize
end

bash "upload image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O qcow2 #{target_raw_path} #{bundled_image_path}

    # upload image
    # export AWS_ACCESS_KEY_ID=#{node.rightimage.aws_access_key_id_for_upload}
    # export AWS_SECRET_ACCESS_KEY=#{node.rightimage.aws_secret_access_key_for_upload}
    # export AWS_CALLING_FORMAT=SUBDOMAIN 
    # /usr/local/bin/s3cmd -v put #{node.rightimage.image_upload_bucket}:#{image_name}.vhd.bz2 /mnt/#{image_name}.vhd.bz2 x-amz-acl:public-read --progress
    # /usr/bin/s3cmd -P put #{bundled_image_path} s3://rightscale-cloudstack-dev/#{bundled_image}
  EOH
end


