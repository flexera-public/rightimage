rs_utils_marker :begin

loopback_fs loopback_file(partitioned?) do
  mount_point guest_root
  action :unmount
end

rs_utils_marker :end
