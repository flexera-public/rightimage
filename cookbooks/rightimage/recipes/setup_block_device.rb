class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device target_raw_root do
  provider "block_device_volume"
  cloud "ec2"
  max_snapshots "1000"
  keep_daily "1000"
  keep_weekly "1000"
  keep_monthly "1000"
  keep_yearly "1000"
  volume_size "41"
  stripe_count "1"
  lineage ri_lineage
  action :create
  persist true
end
