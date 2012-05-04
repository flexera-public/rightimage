rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

loopback_fs loopback_file do
  mount_point guest_root
  partitioned partitioned?
  action :mount
end

rs_utils_marker :end
