class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

include_recipe "rightimage::do_destroy_loopback"

block_device target_raw_root do
  provider "block_device_volume"
  cloud "ec2"
  lineage ri_lineage

  action :reset
end
