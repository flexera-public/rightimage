rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

class Chef::Recipe
  include RightScale::RightImage::Helper
end

# Path to file on disk
full_image_path = target_raw_root+"/"+image_name+"."+image_file_ext

hypervisor = node[:rightimage][:hypervisor]
image_s3_path = hypervisor+"/"+guest_platform+"/"+guest_platform_version+"/"

image_upload_bucket = "rightscale-#{node[:rightimage][:cloud]}-dev"

ros_upload full_image_path do
  provider "ros_upload_s3"
  not_if { node[:rightimage][:cloud] =~ /ec2|google|azure/ }
  user node[:rightimage][:aws_access_key_id]
  password node[:rightimage][:aws_secret_access_key]
  container image_upload_bucket
  remote_path image_s3_path
  action :upload
end
rightscale_marker :end
