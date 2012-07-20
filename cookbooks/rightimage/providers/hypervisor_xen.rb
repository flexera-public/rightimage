class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end


action :install_kernel do
 
  bash "install xen kernel" do
    flags "-ex"
    not_if { hvm? }
    ubuntu_kernel_packages = 'linux-image-virtual linux-headers-virtual grub-legacy-ec2'
    if new_resource.platform_version <= 10.04
      ubuntu_kernel_packages = 'linux-image-ec2 linux-headers-ec2 grub-legacy-ec2'
    end

    code <<-EOH
      # Install to guest. 
      guest_root=#{guest_root}

      case #{new_resource.platform} in
        "centos"|"rhel")
          if [ #{new_resource.platform_version.to_i} -lt 6 ]; then
            chroot $guest_root yum -y remove kernel
            yum -c /tmp/yum.conf --installroot=$guest_root -y install kernel-xen kmod-xfs-xen
          fi

          kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
     
          # Now rebuild ramdisk with xen drivers
          rm -f $guest_root/boot/initrd* $guest_root/initrd*
          chroot $guest_root mkinitrd --with=xennet --with=xenblk --with=ext3 --with=jbd --preload=xenblk -v initrd-$kernel_version $kernel_version
          mv $guest_root/initrd-$kernel_version  $guest_root/boot/.
          ;;
        "ubuntu")
          # Remove any installed kernels
#          for i in `chroot $guest_root dpkg --get-selections linux-headers* linux-image*|sed "s/install//g"`; do chroot $guest_root env DEBIAN_FRONTEND=noninteractive apt-get -y purge $i; done

          chroot $guest_root apt-get -y install #{ubuntu_kernel_packages}
          chroot $guest_root apt-get clean
          ;;
        esac
    EOH
  end

  bash "install grub" do
    flags "-ex"
    only_if { hvm? }
    code <<-EOH
      guest_root=#{guest_root}

      case #{node[:rightimage][:platform]} in
      "ubuntu")
        pkg_cmd="apt-get -y install"
        ;;
      *)
        pkg_cmd="yum -y install"
        ;;
      esac

      chroot $guest_root $pkg_cmd grub
    EOH
  end
end

action :install_tools do
end
