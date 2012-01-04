rs_utils_marker :begin
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
    calc_mb="#{calc_mb}"
    loop_dev="#{loop_dev}"
    loop_map="#{loop_map}"
    root_label="#{node[:rightimage][:root_mount][:label_dev]}"
    source_image="#{source_image}" 
    target_raw_path="#{target_raw_root}/#{os_string}_hd00.raw"

    dd if=/dev/zero of=$target_raw_path bs=1M count=$calc_mb
    losetup $loop_dev $target_raw_path

    sfdisk $loop_dev << EOF
0,1304,L
EOF
    kpartx -a $loop_dev
    mke2fs -F -j $loop_map
    tune2fs -L $root_label $loop_map
    mkdir -p $source_image
    mount $loop_map $source_image
  EOH
end
rs_utils_marker :end
