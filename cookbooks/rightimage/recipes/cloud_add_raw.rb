class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

loop_name="loop0"
loop_dev="/dev/#{loop_name}"

package "qemu"

bash "create loopback fs" do 
  code <<-EOH
    set -e 
    set -x
  
    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]}  
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    base_root="#{base_root}"
    source_image="#{source_image}" 
    target_raw_root="#{target_raw_root}"
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"

    umount -lf #{source_image}/proc || true 
    umount -lf #{guest_root}/proc || true 
    umount -lf #{guest_root} || true
    rm -rf $base_root
    mkdir -p $target_raw_root

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    
    loopdev=#{loop_dev}

    set +e
    losetup -a | grep #{loop_dev}
    [ "$?" == "0" ] && losetup -d #{loop_dev}
    set -e
    losetup $loopdev $target_raw_path
    
    mke2fs -F -j $loopdev
    mkdir -p $guest_root
    mount $loopdev $guest_root
    
    rsync -a $source_image/ $guest_root/

  EOH
end

include_recipe "rightimage::bootstrap_common"

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

    umount -lf $loopdev    
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



