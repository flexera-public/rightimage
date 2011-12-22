class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

rightimage "" do
  action :destroy_loopback
end

package "kpartx" do
  action :install
end if node[:rightimage][:platform] == "ubuntu"

bash "create loopback fs" do 
  flags "-ex"
  code <<-EOH
    DISK_SIZE_GB=#{node[:rightimage][:root_size_gb]} 
    BYTES_PER_MB=1024
    DISK_SIZE_MB=$(($DISK_SIZE_GB * $BYTES_PER_MB))

    loop_dev="#{loop_dev}"
    loop_map="#{loop_map}"
    source_image="#{source_image}" 
    target_raw_path="#{target_raw_root}/#{target_type}0.raw"

    dd if=/dev/zero of=$target_raw_path bs=1M count=$DISK_SIZE_MB    
    losetup $loop_dev $target_raw_path

    sfdisk $loop_dev << EOF
0,1304,L
EOF
    kpartx -a $loop_dev
    mke2fs -F -j $loop_map
    mkdir -p $source_image
    mount $loop_map $source_image
  EOH
end
