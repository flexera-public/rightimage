actions :install_kernel, :install_tools

attribute :hypervisor, :kind_of => String, :name_attribute => true

attribute :platform, :kind_of => String, :equal_to => ["rhel","ubuntu","centos"], :required => true
attribute :platform_version, :kind_of => Float, :required => true

def initialize(name, run_context)
  super(name, run_context)
  provider "rightimage_hypervisor_#{name}"
end
