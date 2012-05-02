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

# This is a fog dependency for version 1.3.1.  0.13.3 causes ssl connection errors, 0.13.2 seems ok. pin until its fixed
# Use rubygems to get around mirror freeze date, for now
r = gem_package "excon" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "0.13.2"
  source "http://rubygems.org"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

%w(formatador multi_json net-scp ruby-hmac).each do |package|
r = gem_package package do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths
end

r = gem_package "fog" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "1.3.1"
  source "http://rubygems.org"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

# Path to file on disk
full_image_path = node[:rightimage][:target_temp_root]}+"/"+image_name+"."+image_file_ext

hypervisor = node[:rightimage][:hypervisor]
image_s3_path = hypervisor+"/"+guest_platform+"/"+platform_version+"/"

image_upload_bucket = "rightscale-#{node[:rightimage][:cloud]}-dev"

rightimage_upload full_image_path do
  provider "rightimage_upload_s3"
  not_if { node[:rightimage][:cloud] == "ec2" }
  remote_path  "#{image_upload_bucket}/#{image_s3_path}"
  action :upload
end
rs_utils_marker :end
