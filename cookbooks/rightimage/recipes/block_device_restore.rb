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
  # Times 2.3 since we need to store 2 raw loopback files, and need a 
  # little extra space to gzip them, take snapshots, etc
  new_volume_size = (node[:rightimage][:root_size_gb].to_f*2.3).ceil
  # This is a hack since our base snapshot size is 23, if we specify less
  # than that it'll error out with an exception.
  new_volume_size = 23 if new_volume_size < 23
  block_device ri_lineage do
    cloud "ec2"
    lineage ri_lineage
    mount_point target_raw_root
    vg_data_percentage "95"
    volume_size new_volume_size.to_s
    stripe_count "1"
    persist true

    action :primary_restore
  end
end

# Delete unneeded loopback file to save disk space.
file loopback_file(!partitioned?) do
  backup false
  action :delete
end

rightscale_marker :end
