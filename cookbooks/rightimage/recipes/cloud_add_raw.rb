class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

source_image = "#{node.rightimage.mount_dir}" 

target_raw = "target.raw"
target_raw_path = "/mnt/#{target_raw}"
target_mnt = "/mnt/target"

loop_name="loop0"
loop_dev="/dev/#{loop_name}"
loop_map="/dev/mapper/#{loop_name}p1"

package "qemu"

bash "create loopback fs" do 
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
    losetup $loopdev $target_raw_path
    
    mke2fs -F -j $loopdev
    mkdir $target_mnt
    mount $loopdev $target_mnt
    
    rsync -a $source_image/ $target_mnt/

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
#    kpartx -d $loopdev
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



