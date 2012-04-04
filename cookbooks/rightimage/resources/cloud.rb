actions :configure, :upload, :package

# Images required for configuration
attribute :guest_root, :kind_of => String, :default => "/mnt/image"
#attribute :platform, :kind_of => String, :equal_to => ["centos","rhel","ubuntu"], :required => true
#attribute :hypervisor, :kind_of => String, :equal_to => ["esxi","xen","kvm"], :required => true
#attribute :arch, :equal_to => ["i386","x86_64"], :default => "x86_64"
#
#attribute :image_name, :kind_of => String
#attribute :image_type, :kind_of => String
#
#attribute :api_key ?
#attribute :api_pass ?
#attribute :api_endpoint ?
#

#   for upload:
#   cloud creds (api_key, api_pass, api_endpoint)
#   target_temp_root (really path/to/file on disk), target_raw_path
#   image_name, image_file_ext (hypervisor derivative)
#   euca: target_temp_root to temporary store creds, can be anywhere?
#

