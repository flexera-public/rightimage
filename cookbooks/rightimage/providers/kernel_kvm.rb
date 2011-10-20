class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install do
 bash "install kvm kernel" do
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{guest_root}

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
