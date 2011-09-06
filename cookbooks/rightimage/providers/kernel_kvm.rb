
action :install do
 
 bash "install kvm kernel" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    kernel_version=#{new_resource.version}
    guest_root=#{new_resource.guest_root}


  case "#{node[:rightimage][:platform]}" in 
    "centos" )
      # The following should be needed when using ubuntu vmbuilder
      yum -c /tmp/yum.conf --installroot=$guest_root -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_ring --with=virtio_net --with=virtio_balloon --with=virtio --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version $guest_root/boot/.
      ;;
    "ubuntu" )
      # Anything need to be done?
      ;;
  esac
      
    EOH
  end
  
  bash "write kernel version to disk" do
    code <<-EOH
       guest_root=#{new_resource.guest_root}
       kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
       echo -n $kernel_version > /tmp/kernel_version
    EOH
  end 
  
  bash "create ramdisk kernel" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    kernel_version=#{new_resource.version}
    guest_root=#{new_resource.guest_root}


  case "#{node[:rightimage][:platform]}" in 
    "centos" )
      # The following should be needed when using ubuntu vmbuilder
      yum -c /tmp/yum.conf --installroot=$guest_root -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_ring --with=virtio_net --with=virtio_balloon --with=virtio --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version $guest_root/boot/.
      ;;
    "ubuntu" )
      # Anything need to be done?
      ;;
  esac
      
    EOH
  end

 
end
