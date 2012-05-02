actions :configure, :upload, :package

attribute :cloud, :kind_of => String, :name_attribute => true
attribute :platform, :kind_of => String, :equal_to => ["centos","rhel","ubuntu"]
attribute :platform_version, :kind_of => Float
attribute :hypervisor, :kind_of => String, :equal_to => ["esxi","xen","kvm"]
attribute :arch, :equal_to => ["i386","x86_64"], :default => "x86_64"

attribute :image_name, :kind_of => String
attribute :image_type, :kind_of => String

def initialize(name, run_context)
  super(name, run_context)
  provider "rightimage_cloud_#{name}"
end

# TBD 
#attribute :api_key ?
#attribute :api_pass ?
#attribute :api_endpoint ?
# guest_root?
# target_temp_root (really path/to/file on disk), target_raw_path

