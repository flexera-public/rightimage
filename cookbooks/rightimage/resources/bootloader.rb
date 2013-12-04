actions :install

attribute :type, :kind_of => String, :name_attribute => true
attribute :cloud, :kind_of => String, :required => true
attribute :hypervisor, :kind_of => String, :required => true
attribute :platform, :kind_of => String, :equal_to => ["rhel","ubuntu","centos"], :required => true
attribute :platform_version, :kind_of => Float, :required => true

def initialize(name, run_context)
  super(name, run_context)
  provider "rightimage_bootloader_#{name}"
end
