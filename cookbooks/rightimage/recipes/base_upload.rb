rightscale_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

file_unpartitioned = loopback_filename(false)+".gz"
file_partitioned   = loopback_filename(true)+".gz"

directory temp_root { recursive true }

bash "compress unpartitioned base image " do
  cwd temp_root 
  flags "-ex"
  creates "#{temp_root}/#{file_unpartitioned}"
  code <<-EOH
    gzip -c #{loopback_file(false)} > #{file_unpartitioned}
  EOH
end

bash "compress partitioned base image" do
  cwd temp_root 
  flags "-ex"
  creates "#{temp_root}/#{file_partitioned}"
  code <<-EOH
    gzip -c #{loopback_file(true)} > #{file_partitioned}
  EOH
end


image_s3_path = guest_platform+"/"+platform_version+"/"+arch+"/"+timestamp[0..3]+"/"
image_upload_bucket = "rightscale-rightimage-base-dev"

# Upload partitioned image
rightimage_upload file_partitioned do
  provider "rightimage_upload_s3"
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload unpartitioned image
rightimage_upload file_unpartitioned do
  provider "rightimage_upload_s3"
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rightscale_marker :end
