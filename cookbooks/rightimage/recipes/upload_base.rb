rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

bash "compress unpartitioned base image " do
  cwd build_root 
  flags "-ex"
  creates "#{build_root}/#{target_type}.raw.gz"
  code <<-EOH
    gzip -c #{target_raw_root}/#{target_type}.raw > #{target_type}.raw.gz
  EOH
end

bash "compress partitioned base image" do
  cwd build_root 
  flags "-ex"
  creates "#{build_root}/#{target_type}0.raw.gz"
  code <<-EOH
    gzip -c #{target_raw_root}/#{target_type}0.raw > #{target_type}0.raw.gz
  EOH
end


image_s3_path = guest_platform+"/"+platform_version+"/"+arch+"/"+timestamp[0..3]]+"/"
image_upload_bucket = "rightscale-rightimage-base-dev"

# Upload partitioned image
rightimage_upload "#{build_root}/#{target_type}0.raw.gz" do
  provider "rightimage_upload_s3"
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

# Upload unpartitioned image
rightimage_upload "#{build_root}/#{target_type}.raw.gz" do
  provider "rightimage_upload_s3"
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end

rs_utils_marker :end
