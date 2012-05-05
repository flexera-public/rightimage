rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end


loopback_fs loopback_file(partitioned?) do
  not_if { node[:rightimage][:root_size_gb] == "10" }
  size_gb node["root_size_gb"].to_i
  action :resize
end

loopback_fs loopback_file(partitioned?) do
  mount_point guest_root
  partitioned partitioned?
  action :mount
end

rightscale_marker :end
