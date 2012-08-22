rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
end

# Location of rightimage_tools gem.
SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"

# Choose correct bucket for base or private cloud.
# Default to dev buckets for RS reasons.
if (node[:rightimage][:build_mode] == "base")
  image_upload_bucket = node[:rightimage][:base_image_bucket]
else
  image_upload_bucket = "rightscale-#{node[:rightimage][:cloud]}-dev"
end

bash "update_s3index" do
  cwd "/tmp"
  flags "-ex"
  environment(cloud_credentials("ec2").merge({'AWS_IMAGE_BUCKET' => image_upload_bucket}))
  code <<-EOH
    #{SANDBOX_BIN_DIR}/update_s3_index
  EOH
end

file "/tmp/index.html" do action :delete end

rightscale_marker :end
