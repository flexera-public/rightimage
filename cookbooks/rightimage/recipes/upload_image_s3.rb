rs_utils_marker :begin

class Chef::Resource
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

rightimage_upload_s3 "Upload image image to s3" do
  not_if { node[:rightimage][:cloud] == "ec2" }

  image_location full_image_path
  s3_path s3_path_full
  bucket full_image_upload_bucket
  action :upload
end
rs_utils_marker :end
