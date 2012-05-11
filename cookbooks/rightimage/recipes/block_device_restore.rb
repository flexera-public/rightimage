rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end


# the mounted? check can't be in a not_if, it errors out Marshal.dump->node 
# when the persist flag is set because its can't serialize the Proc
if mounted?
  Chef::Log::info("Block device already mounted")
else
  block_device ri_lineage do
    cloud "ec2"
    lineage ri_lineage
    mount_point target_raw_root
    vg_data_percentage "50"
    persist true

    action :primary_restore
  end
end

rightscale_marker :end
