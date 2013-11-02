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

remote_file loopback_file_compressed do
  source "http://#{image_upload_bucket}.s3.amazonaws.com/#{image_s3_path}/#{loopback_filename_compressed}"
  backup false
  not_if { ::File.exists?(loopback_file_base) || ::File.exists?(loopback_file_compressed) }
  
  action :create_if_missing
end

execute "bzip2 --decompress #{loopback_file_compressed}" do
  cwd target_raw_root
  not_if { ::File.exists? loopback_file_base }
end

execute "qemu-img create -f qcow2 -o backing_file=#{loopback_file_base} #{loopback_file_backup}" do
  cwd target_raw_root
  not_if { ::File.exists? loopback_file_backup }
end

rightscale_marker :end