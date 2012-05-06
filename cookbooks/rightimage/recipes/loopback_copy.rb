rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end


loopback_fs loopback_file(false) do
  mount_point guest_root+"2"
  device_number 1
  partitioned false
  size_gb node[:rightimage][:root_size_gb].to_i
  action :create
end

bash "copy loopback fs" do
  flags "-e"
  code "rsync -a #{guest_root}/ #{guest_root+'2'}"
end

loopback_fs loopback_file(false) do
  action :unmount
end

rightscale_marker :end
