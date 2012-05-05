rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end


block_device ri_lineage do
  not_if { mounted? }
  cloud "ec2"
  lineage ri_lineage
  mount_point target_raw_root
  vg_data_percentage "50"

  action :primary_restore
end

rightscale_marker :end
