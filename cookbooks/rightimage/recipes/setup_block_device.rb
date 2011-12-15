class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device target_raw_root do
  provider "block_device_volume"
  cloud "ec2"
  volume_size "21"
  stripe_count "1"
  lineage lineage
  action :create
end
