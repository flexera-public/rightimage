class Chef::Resource
  include RightScale::RightImage::Helper
end

action :install_kernel do
 bash "install kvm kernel" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in 
    "centos"|"rhel" )
      [ "#{node[:rightimage][:release].to_f < 6}" == "true" ] && chroot $guest_root yum -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_ring --with=virtio_net --with=virtio_balloon --with=virtio --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version $guest_root/boot/.

      echo 'modules acpiphp' > $guest_root/etc/rc.modules
      chmod 755 $guest_root/etc/rc.modules
 
      set +e
      grep "acpiphp" $guest_root/etc/rc.local
      [ "$?" == "1" ] && echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local
      set -e

      yum -c /tmp/yum.conf --installroot=$guest_root -y install grub
      ;;
    "ubuntu" )
      chroot $guest_root apt-get -y install grub
      ;;
    esac  
  EOH
 end
end

action :install_tools do
end

