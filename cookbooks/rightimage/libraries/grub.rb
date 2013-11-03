module RightScale
  module RightImage
    module Grub

      def grub_kernel_options(cloud)
        options_line = "consoleblank=0"
        if node[:rightimage][:hypervisor].to_s == "xen"
          options_line << " console=hvc0"

          # Start device naming from xvda instead of xvde (w-4893)
          # https://bugzilla.redhat.com/show_bug.cgi?id=729586
          if node[:rightimage][:platform] == "centos" && node[:rightimage][:platform_version].to_f >= 6.3
            options_line << " xen_blkfront.sda_is_xvda=1"
          end
        end

        if cloud.to_s == "azure"
          # Ensure that all SCSI devices mounted in your kernel include an I/O timeout of 300 seconds or more. (w-5331)
          options_line << " rootdelay=300 console=ttyS0"

          if node[:rightimage][:platform] == "centos"
            options_line <<  " numa=off"
          end
        end
        options_line
      end

      def grub_package
        if node[:rightimage][:platform] == "ubuntu"
          "grub2"
        else
          "grub"
        end
      end

      def grub_initrd
        ::File.basename(Dir.glob("#{guest_root}/boot/initr*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_kernel
        ::File.basename(Dir.glob("#{guest_root}/boot/vmlinuz*").sort_by { |f| File.mtime(f) }.last)
      end

      def grub_root
        "(hd0,0)"
      end

      def grub_root_device
        node[:rightimage][:root_mount][:dev]
      end
    end
  end
end