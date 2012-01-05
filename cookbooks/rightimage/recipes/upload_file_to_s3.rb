rs_utils_marker :begin
class Chef::Resource::RightimageUploadS3
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

packages = ["libxml2-devel", "libxslt-devel"]
packages.map!{|a| a.sub('devel','dev')} if node[:platform] == "ubuntu"
packages.each do |p| 
  r = package p do 
    action :nothing 
  end
  r.run_action(:install)
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

rightimage_upload_s3 "Upload image image to s3" do
  not_if { node[:rightimage][:cloud] == "ec2" }

  image_location full_image_path
  s3_path s3_path_full
  bucket full_image_upload_bucket
  action :upload
end
rs_utils_marker :end
