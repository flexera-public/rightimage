require 'chef/resource'

class Chef
  class Resource
    class LoopbackFs < Chef::Resource



      def initialize(name, run_context = nil)
        super
        @resource_name = :loopback_fs          # Bind ourselves to the name with an underscore
        @provider = Chef::Provider::LoopbackFs # We need to tie to our provider
        @action = :create                     # Default Action Goes here
        @allowed_actions = [ :create, :unmount, :mount, :clone, :nothing ]

        # Defaults
        @source = name  
        @destination = nil
        @size_gb = 10
        @mount_point = "/mnt/image"
        @label = "ROOT"
        @device_number = 0
        @bind_devices = true
        @partitioned = true
      end

      # Define the attributes we set defaults for
      def source(arg=nil)
        set_or_return(:source, arg, :kind_of => String)
      end

      def destination(arg=nil)
        set_or_return(:destination, arg, :kind_of => String)
      end

      def size_gb(arg=nil)
        set_or_return(:size_gb, arg, :kind_of => Integer)
      end

      def mount_point(arg=nil)
        set_or_return(:mount_point, arg, :kind_of => String)
      end

      def label(arg=nil)
        set_or_return(:label, arg, :kind_of => String)
      end

      def device_number(arg=nil)
        set_or_return(:device_number, arg, :kind_of => Integer)
      end

      def bind_devices(arg=nil)
        set_or_return(:bind_devices, arg, :kind_of => [ TrueClass, FalseClass ])
      end

      def partitioned(arg=nil)
        set_or_return(:partitioned, arg, :kind_of => [ TrueClass, FalseClass ])
      end
    end
  end
end

