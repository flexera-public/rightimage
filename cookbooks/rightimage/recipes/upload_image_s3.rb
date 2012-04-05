rs_utils_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

class Chef::Recipe
  include RightScale::RightImage::Helper
end

# This is a fog dependency.  The gem dependency code has a bug and causes fog install to fail unless we install this explicitly before
r = gem_package "net-ssh" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "2.1.4"
  action :nothing
end
r.run_action(:install)

r = gem_package "fog" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

# Path to file on disk
full_image_path = node[:rightimage][:target_temp_root]}+"/"+image_name+"."+image_file_ext

hypervisor = node[:rightimage][:virtual_environment]
image_s3_path = hypervisor+"/"+guest_platform+"/"+release_number+"/"

image_upload_bucket = "rightscale-#{node[:rightimage][:cloud]}-dev"

rightimage_upload full_image_path do
  provider "rightimage_upload_s3"
  not_if { node[:rightimage][:cloud] == "ec2" }
  s3_path image_s3_path
  bucket image_upload_bucket
  action :upload
end
rs_utils_marker :end
