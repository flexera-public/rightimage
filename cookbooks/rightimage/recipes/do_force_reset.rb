rs_utils_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end

class Chef::Resource::BlockDevice
  include RightScale::RightImage::Helper
end

include_recipe "rightimage::do_destroy_loopback"

block_device ri_lineage do
  cloud "ec2"
  lineage ri_lineage
  vg_data_percentage "50"

  action :reset
end
rs_utils_marker :end
