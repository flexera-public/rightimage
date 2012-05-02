actions :package

attribute :platform, :kind_of => String, :equal_to => ["rhel","ubuntu","centos"]
attribute :platform_version, :kind_of => Float
attribute :image_name, :kind_of => String

def initialize(name, run_context)
  super(name, run_context)
  provider "rightimage_image_#{name}"
end
