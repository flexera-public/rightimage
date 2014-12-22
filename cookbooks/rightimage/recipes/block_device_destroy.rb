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
  primary_cloud "ec2"
  hypervisor "xen"
  lineage ri_lineage
  mount_point target_raw_root
  vg_data_percentage "50"

  action :reset
end
rightscale_marker :end
