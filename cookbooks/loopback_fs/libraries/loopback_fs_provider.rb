
require "chef/provider"
require "chef/mixin/shell_out"


class Chef
  class Provider
    class LoopbackFs < Chef::Provider

      include Chef::Mixin::ShellOut

      def load_current_resource
        @current_resource ||= Chef::Resource::LoopbackFs.new(new_resource.name)
        @current_resource
      end

      def initialize(*args)
        super 
        @mount_point = nil
        @device_number = 1
      end

      def bind_devices(mount_point)
        shell_out  "umount #{mount_point}/proc"
        shell_out! "mkdir -p #{mount_point}/proc"
        shell_out! "mount --bind /proc #{mount_point}/proc"

        shell_out  "umount #{mount_point}/sys"
        shell_out! "mkdir -p #{mount_point}/sys"
        shell_out! "mount --bind /sys #{mount_point}/sys"

        shell_out "umount #{mount_point}/dev"
        shell_out! "mkdir -p #{mount_point}/dev"
        shell_out! "mount -t devtmpfs none #{mount_point}/dev"
      end

      def unbind_devices(mount_point)
        shell_out "umount -lf #{mount_point}/dev/pts"
        shell_out "umount -lf #{mount_point}/dev"
        shell_out "umount -lf #{mount_point}/proc"
        shell_out "umount -lf #{mount_point}/sys"
      end

      def create_loopback(source, size_gb, device_num, partitioned)
        Chef::Log::info("Creating #{size_gb}GB volume at #{source}")
        loop_device = "#{::LoopbackFs.loopback_device}#{device_num}"

        shell_out! "qemu-img create -f qcow2 #{source} #{size_gb}G"
        create_qemu_nbd(source, device_num)

        if partitioned
          shell_out "parted -s #{loop_device} mklabel msdos"
          shell_out "parted -s #{loop_device} mkpart primary ext2 1024k 100% -a minimal"
          shell_out "parted -s #{loop_device} set 1 boot on"
        end
      end

      def setup_loopback(source, device_num)
        loop_device = "#{::LoopbackFs.loopback_device}#{device_num}"
        Chef::Log::info("Creating loopback device at #{loop_device}")
        create_qemu_nbd(source, device_num)
      end

      def create_qemu_nbd(source, device_num)
        loop_device = "#{::LoopbackFs.loopback_device}#{device_num}"
        unless ::File.exists?(loop_device)
          shell_out! "modprobe nbd max_part=16"
        end
        shell_out! "qemu-nbd -n -c #{loop_device} #{source}"
        sleep 1
      end

      def setup_mapper(size_gb, device_num, partitioned)
        loop_device = "#{::LoopbackFs.loopback_device}#{device_num}"

        if partitioned
          # So this bit of indirection helps the grub2 install to work - grub2 
          # normally freaks out if the partition is in /dev/mapper and the loopback
          # device itself is mounted in /dev, so keep them both in the same place
          # so that grub2-install can link them together properly
          fake_device = "/dev/mapper/sda#{device_num}"
          fake_dev_name = ::File.basename(fake_device)
          size_blocks = size_gb * 2097152
          shell_out! "echo '0 #{size_blocks} linear #{loop_device} 0' | dmsetup create #{fake_dev_name}"
          shell_out! "kpartx -s -a #{fake_device}"

          fake_partition = "#{fake_device}p1"
          Chef::Log::info("Paritioning device and creating device map to #{fake_partition}")
        else
          fake_partition = loop_device
          Chef::Log::info("Unpartioned volume, using #{loop_device}")

        end
        fake_partition
      end

      def mount_partition(loop_partition, mount_point)
        Chef::Log::info("Mounting volume #{loop_partition} to #{mount_point}")

        shell_out! "rm -rf #{mount_point}"
        shell_out! "mkdir -p #{mount_point}"
        shell_out! "mount -t ext2 #{loop_partition} #{mount_point}"
      end

      def format_partition(loop_partition, root_label)
        Chef::Log::info("Formatting volume as ext2")

        shell_out! "mke2fs -F -j #{loop_partition}"
        shell_out! "tune2fs -L #{root_label} #{loop_partition}"
      end

      def action_create

        unless ::File.exists? new_resource.source
          create_loopback(new_resource.source, new_resource.size_gb, new_resource.device_number, new_resource.partitioned)

          loop_partition = setup_mapper(new_resource.size_gb, new_resource.device_number, new_resource.partitioned)
          format_partition(loop_partition, new_resource.label)
          mount_partition(loop_partition, new_resource.mount_point)
          bind_devices(new_resource.mount_point) if new_resource.bind_devices
        end


      end

      def action_nothing
      end

      def action_unmount

        shell_out "sync"

        unbind_devices(new_resource.mount_point)

        shell_out "umount -lf #{new_resource.mount_point}"

        loop_device = "#{::LoopbackFs.loopback_device}#{new_resource.device_number}"
        fake_device = "/dev/mapper/sda#{new_resource.device_number}"

        if ::File.exists? fake_device
          shell_out! "kpartx -s -d #{fake_device}"
          shell_out! "dmsetup remove #{fake_device}"
        end

        shell_out! "qemu-nbd -d #{loop_device}"
      end

      def action_mount

        mounted = shell_out!("mount").stdout.split("\n")
        if mounted.any? { |line| line.include? new_resource.mount_point }
          return true
        end

        setup_loopback(new_resource.source, new_resource.device_number)
        loop_partition = setup_mapper(new_resource.size_gb, new_resource.device_number, new_resource.partitioned)
        mount_partition(loop_partition, new_resource.mount_point)
        bind_devices(new_resource.mount_point) if new_resource.bind_devices
      end

      def action_clone
        Chef::Log::info("Cloning by creating #{new_resource.destination} backed by #{new_resource.source}")
        raise "No destination provided for clone action" if new_resource.destination.to_s.empty?
        shell_out! "qemu-img create -f qcow2 -o backing_file=#{new_resource.source} #{new_resource.destination}"
      end

    end
  end
end
