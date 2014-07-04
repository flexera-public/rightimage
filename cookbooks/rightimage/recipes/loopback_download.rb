rightscale_marker :begin

class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end

image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+mirror_freeze_date[0..3]
image_upload_bucket = node[:rightimage][:base_image_bucket]

directory target_raw_root do
  action :create
end

# First try to download from production bucket
remote_file loopback_file_compressed do
  source "http://#{image_upload_bucket}.s3.amazonaws.com/#{image_s3_path}/#{loopback_filename_compressed}"
  ignore_failure true
  backup false
  not_if { ::File.size?(loopback_file_base) || ::File.size?(loopback_file_compressed) }
  
  action :create
end

# If not in production bucket, try dev bucket
remote_file loopback_file_compressed do
  source "http://#{image_upload_bucket}-dev.s3.amazonaws.com/#{image_s3_path}/#{loopback_filename_compressed}"
  backup false
  not_if { ::File.size?(loopback_file_base) || ::File.size?(loopback_file_compressed) }
  
  action :create
end

execute "tar xjf #{loopback_file_compressed}" do
  cwd target_raw_root
  not_if { ::File.exists? loopback_file_base }
end

loopback_fs loopback_file_base do
  not_if { ::File.exists?(loopback_file_backup) || do_loopback_resize }
  destination loopback_file_backup
  action :clone
end

rightscale_marker :end
