actions :create, :unmount, :mount, :resize

attribute :source, :kind_of => String, :name_attribute => true
attribute :size_gb, :kind_of => Integer, :default => 10
attribute :mount_point, :kind_of => String, :default => "/mnt/image"
attribute :label, :kind_of => String, :default => "ROOT"
attribute :device_number, :kind_of => Integer, :default => 0
attribute :partitioned, :kind_of => [TrueClass, FalseClass], :default => true
