actions :package

attribute :guest_root, :kind_of => String
attribute :platform, :kind_of => String, :equal_to => ["rhel","ubuntu","centos"]
attribute :hypervisor, :kind_of => String, :equal_to => ["esxi","kvm","xen"]
attribute :image_name, :kind_of => String
