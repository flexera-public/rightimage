rs_utils_marker :begin
class Chef::Resource::RightimageUploadS3
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

# This is a fog dependency.  The gem dependency code has a bug and causes fog install to fail unless we install this explicitly before
r = gem_package "net-ssh" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "2.1.4"
  action :nothing
end
r.run_action(:install)

# This is a fog dependency for version 1.13.1.  0.13.3 causes ssl connection errors, 0.13.2 seems ok. pin until its fixed
r = gem_package "excon" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "0.13.2"
  action :nothing
end
r.run_action(:install)
Gem.clear_paths

r = gem_package "fog" do
  gem_binary "/opt/rightscale/sandbox/bin/gem"
  version "1.13.1"
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
