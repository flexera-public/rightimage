rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

package "rsync"

# TODO: Check for resize option on qemu. Will need to resize the actual disk too.

# If the image is unpartitioned we use resize2fs, if its partitioned we 
# create a new loopback file of the desired size, mount it, and copy over
# then replace the old file since that works equally well for growing/shrinking
# and was simpler/quicker than resizing the partitions disk
# Resize will leave the loopback fs in an unmounted state
#
# TBD: Resize functionality should be pushed into loopback cookbook at some point
# but will need a little bit of a refactor for that.
# TBD: Make a second go at trying to resize the partitions in place
#
log "Resizing loopback filesystem to (#{node[:rightimage][:root_size_gb]}" do 
  only_if { do_loopback_resize }
end
log "Resize skipped, desired file size (#{node[:rightimage][:root_size_gb]}) and actual size are the same" do
  not_if { do_loopback_resize }
end

loopback_fs loopback_file_base do
  only_if { do_loopback_resize }
  bind_devices false
  mount_point guest_root
  device_number 0
  action :mount
end

loopback_fs loopback_file_base+".tmp" do
  only_if { do_loopback_resize }
  bind_devices false
  mount_point guest_root+"2"
  device_number 1
  size_gb node[:rightimage][:root_size_gb].to_i
  action :create
end

bash "copy loopback fs" do
  only_if { do_loopback_resize }
  flags "-e"
  code "rsync -a #{guest_root}/ #{guest_root+'2'}"
end

loopback_fs loopback_file_base do
  only_if { do_loopback_resize }
  mount_point guest_root
  action :unmount
end

loopback_fs loopback_file_base+".tmp" do
  only_if { do_loopback_resize }
  mount_point guest_root+"2"
  action :unmount
end

bash "replace old file" do
  only_if { do_loopback_resize }
  flags "-ex"
  code "mv #{loopback_file_base}.tmp #{loopback_file_base}"
end

loopback_fs loopback_file_base do
  only_if { do_loopback_resize }
  destination loopback_file_backup
  action :clone
end

rightscale_marker :end
