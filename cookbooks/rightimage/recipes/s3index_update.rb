rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

# Location of rightimage_tools gem.
SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"

# Replace with more general bucket var.
image_upload_bucket = node[:rightimage][:base_image_bucket]

bash "update_s3index" do
  cwd "/tmp"
  flags "-ex"
  environment(cloud_credentials("ec2"))
  code <<-EOH
    #{SANDBOX_BIN_DIR}/update_s3_index #{image_upload_bucket}
  EOH
end

file "/tmp/index.html" do action :delete end

rightscale_marker :end
