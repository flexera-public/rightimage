class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

bash "create loopback fs" do 
  flags "-ex"
  code <<-EOH
    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]} 
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    loop_name="loop0"
    loop_dev="/dev/$loop_name"
    loop_map="/dev/mapper/${loop_name}p1"
    source_image="#{source_image}" 
    target_raw_path="#{target_raw_path}"

    umount -lf $source_image/dev || true
    umount -lf $source_image/proc || true
    umount -lf $source_image/sys || true
    umount -lf $source_image || true

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    

    set +e
    losetup -a | grep $loop_dev
    [ "$?" == "0" ] && losetup -d $loop_dev
    set -e
    losetup $loop_dev $target_raw_path

    sfdisk $loop_dev << EOF
0,1304,L
EOF
    kpartx -a $loop_dev
    mke2fs -F -j $loop_map
    mount $loop_map $source_image
  EOH
end
