rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

# Resize will leave the loopback fs in an unmounted state
source_size_gb = (::File.size(loopback_file(partitioned?))/1024/1024/1024).to_f.round
if node[:rightimage][:root_size_gb].to_i == source_size_gb
  log "Resize skipped, desired file size (#{node[:rightimage][:root_size_gb]}) and actual size_size (#{source_size_gb}) are the same"
else
  if partitioned?
    loopback_fs loopback_file(true) do
      mount_point guest_root
      device_number 0
      partitioned true
      action :mount
    end

    loopback_fs loopback_file(true)+".tmp" do
      mount_point guest_root+"2"
      device_number 1
      partitioned true
      size_gb node[:rightimage][:root_size_gb].to_i
      action :create
    end

    bash "copy loopback fs" do
      flags "-e"
      code "rsync -a #{guest_root}/ #{guest_root+'2'}"
    end

    loopback_fs loopback_file(true) do
      mount_point guest_root
      action :unmount
    end

    loopback_fs loopback_file(true)+".tmp" do
      mount_point guest_root+"2"
      action :unmount
    end

    bash "replace old file" do
      flags "-ex"
      code "mv #{loopback_file(true)}.tmp #{loopback_file(true)}"
    end
  else
    loopback_fs loopback_file(false) do
      mount_point guest_root
      action :unmount
    end
    loopback_fs loopback_file(false) do
      mount_point guest_root
      size_gb node[:rightimage][:root_size_gb].to_i
      partitioned false
      action :resize
    end
  end
end

rightscale_marker :end
