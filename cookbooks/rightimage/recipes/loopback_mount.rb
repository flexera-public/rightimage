rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end


loopback_fs loopback_file(partitioned?) do
  mount_point guest_root
  partitioned partitioned?
  action [:resize, :mount]
end

rightscale_marker :end
