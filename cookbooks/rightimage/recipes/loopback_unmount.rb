rightscale_marker :begin

loopback_fs loopback_file(partitioned?) do
  mount_point guest_root
  action :unmount
end

rightscale_marker :end
