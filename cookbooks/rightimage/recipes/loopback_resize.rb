rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

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

if partitioned?
  loopback_fs loopback_file(true) do
    only_if { do_loopback_resize }
    mount_point guest_root
    device_number 0
    partitioned true
    action :mount
  end

  loopback_fs loopback_file(true)+".tmp" do
    only_if { do_loopback_resize }
    mount_point guest_root+"2"
    device_number 1
    partitioned true
    size_gb node[:rightimage][:root_size_gb].to_i
    action :create
  end

  bash "copy loopback fs" do
    only_if { do_loopback_resize }
    flags "-e"
    code "rsync -a #{guest_root}/ #{guest_root+'2'}"
  end

  loopback_fs loopback_file(true) do
    only_if { do_loopback_resize }
    mount_point guest_root
    action :unmount
  end

  loopback_fs loopback_file(true)+".tmp" do
    only_if { do_loopback_resize }
    mount_point guest_root+"2"
    action :unmount
  end

  bash "replace old file" do
    only_if { do_loopback_resize }
    flags "-ex"
    code "mv #{loopback_file(true)}.tmp #{loopback_file(true)}"
  end
else
  loopback_fs loopback_file(false) do
    only_if { do_loopback_resize }
    mount_point guest_root
    action :unmount
  end
  loopback_fs loopback_file(false) do
    only_if { do_loopback_resize }
    mount_point guest_root
    size_gb node[:rightimage][:root_size_gb].to_i
    partitioned false
    action :resize
  end
end

rightscale_marker :end
