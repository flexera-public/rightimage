actions :upload

# pathname/bucket to upload the remote file to
attribute :remote_path, :kind_of => String

attribute :endpoint, :kind_of => String
attribute :user, :kind_of => String
attribute :password, :kind_of => String

# Full path to local file on disk
attribute :file, :kind_of => String, :name_attribute => true
