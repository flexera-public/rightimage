rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

r = gem_package "s3sync" do
  gem_binary "/usr/bin/gem"
  action :nothing
end
r.run_action(:install)

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

bash "upload unpartitioned base image" do
  cwd build_root 
  not_if {`curl -o /dev/null --head --connect-timeout 10 --fail --silent --write-out %{http_code} http://#{base_image_upload_bucket}.s3.amazonaws.com/#{s3_path_base}/#{target_type}.raw.gz`.strip == "200" }
  flags "-ex"
  environment(cloud_credentials("ec2"))
  code <<-EOH
    s3cmd put #{base_image_upload_bucket}:#{s3_path_base}/#{target_type}.raw.gz #{target_type}.raw.gz x-amz-acl:public-read
  EOH
end

bash "upload partitioned base image" do
  cwd build_root 
  not_if {`curl -o /dev/null --head --connect-timeout 10 --fail --silent --write-out %{http_code} http://#{base_image_upload_bucket}.s3.amazonaws.com/#{s3_path_base}/#{target_type}0.raw.gz`.strip == "200" }
  flags "-ex"
  environment(cloud_credentials("ec2"))
  code <<-EOH
    s3cmd put #{base_image_upload_bucket}:#{s3_path_base}/#{target_type}0.raw.gz #{target_type}0.raw.gz x-amz-acl:public-read
  EOH
end
rs_utils_marker :end
