rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

loopback_fs loopback_file do
  action :unmount
end

block_device ri_lineage do
  action :reset
end
rightscale_marker :end
