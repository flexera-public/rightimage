rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

# This will make the file smaller.
bash "convert base image" do
  cwd target_raw_root
  flags "-ex"
  code <<-EOH
    qemu-img convert -f qcow2 -O qcow2 #{loopback_file} #{loopback_file}.new
    mv #{loopback_file}.new #{loopback_file}
  EOH
end

bash "compress partitioned base image" do
  cwd target_raw_root
  flags "-ex"
  not_if { ::File.exists?(loopback_file_compressed) && (::File.mtime(loopback_file_compressed) > ::File.mtime(loopback_file)) }
  code "tar cjf #{loopback_file_compressed} #{loopback_filename}"
end


image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+mirror_freeze_date[0..3]+"/"
image_upload_bucket = node[:rightimage][:base_image_bucket]

# Upload partitioned image
rightimage_upload loopback_file_compressed do
  provider "ros_upload_s3"
  user node[:rightimage][:aws_access_key_id]
  password node[:rightimage][:aws_secret_access_key]
  container image_upload_bucket
  remote_path  image_s3_path
  action :upload
end

rightscale_marker :end
