actions :install_kernel, :install_tools

attribute :guest_root, :kind_of => String
attribute :platform, :kind_of => String, :equal_to => ["rhel","ubuntu","centos"]
attribute :hypervisor, :kind_of => String, :equal_to => ["esxi","kvm","xen"], :name_attribute=>true
attribute :image_name, :kind_of => String
