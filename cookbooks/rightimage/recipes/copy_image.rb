class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

bash "create nonpartitioned image" do
  flags "-ex"
  code <<-EOH
     DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]} 
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    loop_dev="/dev/loop1"
    source_image="#{source_image}"
    source_image2="/mnt/image2"
    target_raw_path="#{target_raw_path}"

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    losetup $loop_dev $target_raw_path
    mke2fs -F -j $loop_dev
    rm -rf $source_image2
    mkdir -p $source_image2
    mount $loop_dev $source_image2
    rsync -a $source_image/ $source_image2/
    umount -lf $source_image2
    losetup -d $loop_dev
  EOH
end
