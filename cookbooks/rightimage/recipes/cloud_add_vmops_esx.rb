class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

raise "ERROR: you must set your virtual_environment to esx!"  if node[:rightimage][:virtual_environment] != "esx"

source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

bundled_image = "#{image_name}.vmdk"
bundled_image_path = "/mnt/#{bundled_image}"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

bash "create cloudstack-esx loopback fs" do 
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

bash "install vmware tools" do 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    target_mnt=#{target_mnt}
    TMP_DIR=/tmp/vmware_tools
    chroot $target_mnt mkdir -p $TMP_DIR
    chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -o $TMP_DIR/dsa.pub
    chroot $target_mnt curl http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -o $TMP_DIR/rsa.pub
    chroot $target_mnt rpm --import $TMP_DIR/dsa.pub
    chroot $target_mnt rpm --import $TMP_DIR/rsa.pub
    cat $target_mnt/etc/yum.repos.d/vmware-tools.repo <<EOF
[vmware-tools] 
name=VMware Tools 
baseurl=http://packages.vmware.com/tools/esx/latest/rhel5/x86_64
enabled=1 
gpgcheck=1
EOF
   chroot $target_mnt yum -y install vmware-tools
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

bash "convert image" do 
  cwd File.dirname target_raw_path
  code <<-EOH
    set -e
    set -x
    qemu-img convert -O vmdk #{target_raw_path} #{bundled_image_path}
  EOH
end


