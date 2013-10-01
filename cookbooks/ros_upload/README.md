# DESCRIPTION:

This is a utility cookbook to help upload files to a remote object store (s3 supported)

# REQUIREMENTS:

Ruby 1.8+ and rubygems.  This cookbook relies on fog and will install the version
it needs.

# ATTRIBUTES:

No attributes. Currently not usable as a standalone cookbook, meant to be called
from other cookbooks only. Note that a trailing slash on remote_path makes a difference.
If there is a trailing slash, the filename will be appended to the remote path.
If there is not a trailing slash, the file will be renamed.

# USAGE:
  
    include_recipe "ros_upload" # installs fog

    ros_upload "/path/to/file" do
      provider  "ros_upload_s3"
      user      node[:cookbook][:aws_access_key_id]
      password  node[:cookbook][:aws_secret_access_key]
      container node[:cookbook][:s3_bucket]
      remote_path "subdir/"
      action :upload
    end
