class Chef::Resource
  include RightScale::RightImage::Helper
end

action :install_kernel do

  # this is cloudstack (maybe openstack?) specific?
  # maybe move to cloud providers later
  bash "add acpi module" do
    flags "-x"
    code <<-EOH
    guest_root=#{guest_root}
    set +e
    case "#{node[:rightimage][:platform]}" in
    "centos" )
      grep "acpiphp" $guest_root/etc/rc.local
      [ "$?" == "1" ] && echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local
      grep "acpiphp" $guest_root/etc/rc.modules
      [ "$?" == "2" -o "$?" == "1" ] && echo '/sbin/modprobe acpiphp' > $guest_root/etc/rc.modules
      chmod 755 $guest_root/etc/rc.modules
      ;;
    "ubuntu" )
      echo '#!/bin/sh -e' > $guest_root/etc/rc.local
      echo "/sbin/modprobe acpiphp" >> $guest_root/etc/rc.local
      echo "acpiphp" >> /etc/modules
      ;;
    esac
  EOH
 end

 bash "install kvm kernel" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}

    case "#{new_resource.platform}" in
    "centos"|"rhel" )
      [ "#{new_resource.platform_version.to_i < 6}" == "true" ] && chroot $guest_root yum -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      if [ #{node[:rightimage][:platform_version].to_i} -le 6 ]; then
        ramdisk="initrd-${kernel_version}"
      else
        ramdisk="initramfs-${kernel_version}.img"
      fi

      rm -f $guest_root/boot/initr* $guest_root/initr*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_ring --with=virtio_net --with=virtio_balloon --with=virtio --with=virtio_blk --with=virtio_scsi --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v $ramdisk $kernel_version
      mv $guest_root/$ramdisk $guest_root/boot/.
      ;;
    "ubuntu" )
      ;;
    esac
  EOH
 end
end

action :install_tools do
end

