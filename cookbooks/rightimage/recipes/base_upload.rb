rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

gem_package_fog

file_unpartitioned = ::File.join(temp_root, loopback_filename(false)+".gz")
file_partitioned   = ::File.join(temp_root, loopback_filename(true)+".gz")

directory temp_root { recursive true }

bash "compress unpartitioned base image " do
  cwd temp_root
  flags "-ex"
  creates file_unpartitioned
  code "gzip -c #{loopback_file(false)} > #{file_unpartitioned}"
end

bash "compress partitioned base image" do
  cwd temp_root
  flags "-ex"
  creates file_partitioned
  code "gzip -c #{loopback_file(true)} > #{file_partitioned}"
end


image_s3_path = guest_platform+"/"+platform_version+"/"+arch+"/"+timestamp[0..3]+"/"
image_upload_bucket = node[:rightimage][:base_image_bucket]

# Upload partitioned image
rightimage_upload file_partitioned do
  provider "rightimage_upload_s3"
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload unpartitioned image
rightimage_upload file_unpartitioned do
  provider "rightimage_upload_s3"
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
