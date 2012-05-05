actions :install

attribute :platform, :kind_of => String, :name_attribute => true
attribute :platform_version, :kind_of => Float, :required => true
attribute :arch, :equal_to => ["i386","x86_64"], :default => "x86_64"

def initialize(name, run_context)
  super(name, run_context)
  provider "rightimage_os_#{name}"
end
