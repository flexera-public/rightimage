rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

block_device ri_lineage do
  action :snapshot
end

block_device ri_lineage do
  action :primary_backup
end
rightscale_marker :end
