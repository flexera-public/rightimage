class Chef::Resource::Execute
  include RightScale::RightImage::Helper
end

#rs_utils_marker :begin

block_device node[:rightimage][:ebs_mount_dir] do
  provider "block_device_volume"
  cloud node[:cloud][:provider]
  lineage lineage_name

  action :reset
end

#rs_utils_marker :end
