class Chef::Resource
  include RightScale::RightImage::Helper
end

action :install_kernel do

  # this is cloudstack (maybe openstack?) specific?
  # maybe move to cloud providers later
  bash "add acpi module" do
    flags "-x"
    not_if { node[:rightimage][:cloud] == "google" }
    code <<-EOH
    guest_root=#{guest_root}
    set +e
    case "#{node[:rightimage][:platform]}" in 
    "centos" )
      grep "acpiphp" $guest_root/etc/rc.local
      [ "$?" == "1" ] && echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local
      grep "acpiphp" $guest_root/etc/rc.modules
      [ "$?" == "2" -o "$?" == "1" ] && echo 'modules acpiphp' > $guest_root/etc/rc.modules
      chmod 755 $guest_root/etc/rc.modules
      ;;
    "ubuntu" )
      echo '#!/bin/sh -e' > $guest_root/etc/rc.local
      echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local
      echo "exit 0" >> $guest_root/etc/rc.local
      echo "acpiphp" >> /etc/modules
      ;;
    esac
  EOH
 end

 bash "install kvm kernel" do
  flags "-ex"
  not_if { node[:rightimage][:cloud] == "google" }
  code <<-EOH
    guest_root=#{guest_root}

    case "#{new_resource.platform}" in 
    "centos"|"rhel" )
      [ "#{new_resource.platform_version.to_i < 6}" == "true" ] && chroot $guest_root yum -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_ring --with=virtio_net --with=virtio_balloon --with=virtio --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version $guest_root/boot/.

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

