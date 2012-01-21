rs_utils_marker :begin
class Chef::Resource::RightimageUpload
  include RightScale::RightImage::Helper
end

class Chef::Resource::RubyBlock
  include RightScale::RightImage::Helper
end

rightimage_upload "Upload cloudstack image" do
  provider "rightimage_upload_vmops"
  action :upload
end
rs_utils_marker :end
