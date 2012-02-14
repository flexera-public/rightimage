rs_utils_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device ri_lineage do
  cloud "ec2"
  lineage ri_lineage
  mount_point target_raw_root 

  action :snapshot
end

block_device ri_lineage do
  cloud "ec2"
  lineage ri_lineage
  mount_point target_raw_root 

  action :primary_backup
end
rs_utils_marker :end
