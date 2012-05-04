rs_utils_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end


block_device ri_lineage do
  cloud "ec2"
  lineage ri_lineage
  mount_point target_raw_root
  vg_data_percentage "50"

  action :primary_restore
end

loopback_fs loopback_file do
  not_if { node[:rightimage][:root_size_gb] == "10" }
  size_gb node["root_size_gb"].to_i
  action :resize
end

loopback_fs loopback_file do
  mount_point guest_root
  partitioned true
  action :mount
end

rs_utils_marker :end
