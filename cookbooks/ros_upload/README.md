# DESCRIPTION:

This is a utility cookbook to help upload files to a remote object store (s3 supported)

# REQUIREMENTS:

Ruby 1.8+ and rubygems.  This cookbook relies on fog and will install the version
it needs.

# ATTRIBUTES:

No attributes. Currently not usable as a standalone cookbook, meant to be called
from other cookbooks only.

# USAGE:

    ros_upload "/path/to/file" do
      provider  "ros_upload_s3"
      user      node[:cookbook][:aws_access_key_id]
      password  node[:cookbook][:aws_secret_access_key]
      container node[:cookbook][:s3_bucket]
      remote_path "subdir/file"
      action :upload
    end
