rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

gem_package_fog

file_partitioned   = ::File.join(temp_root, loopback_filename+".gz")

directory temp_root { recursive true }

bash "compress partitioned base image" do
  cwd temp_root
  flags "-ex"
  creates file_partitioned
  code "gzip -c #{loopback_file} > #{file_partitioned}"
end


image_s3_path = guest_platform+"/"+guest_platform_version+"/"+guest_arch+"/"+timestamp[0..3]+"/"
image_upload_bucket = node[:rightimage][:base_image_bucket]

# Upload partitioned image
rightimage_upload file_partitioned do
  provider "rightimage_upload_s3"
  endpoint 's3-us-west-2.amazonaws.com'
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
