rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

directory target_raw_root do
  action :create
end

loopback_fs loopback_file do
  mount_point guest_root
  size_gb node[:rightimage][:root_size_gb].to_i
  action :create
end

rightscale_marker :end
