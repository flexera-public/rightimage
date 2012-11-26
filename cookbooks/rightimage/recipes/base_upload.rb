rightscale_marker :begin
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

gem_package_fog

directory(::File.dirname(loopback_file_gz)) { recursive true }

bash "compress partitioned base image" do
  cwd temp_root
  flags "-ex"
  not_if { ::File.exists?(loopback_file_gz) && (::File.mtime(loopback_file_gz) > ::File.mtime(loopback_file)) }
  code "gzip -c #{loopback_file} > #{loopback_file_gz}"
end


image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+timestamp[0..3]+"/"
image_upload_bucket = node[:rightimage][:base_image_bucket]

# Upload partitioned image
rightimage_upload file_partitioned do
  provider "rightimage_upload_s3"
  user node[:rightimage][:aws_access_key_id]
  password node[:rightimage][:aws_secret_access_key]
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
