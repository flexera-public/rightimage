class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install do
 
  bash "install esxi ramdisk" do 
    code <<-EOH
      set -e 
      set -x
#      kernel_version=#{new_resource.version}
      
      # Install to guest. 
#      guest_root=#{new_resource.guest_root}
      guest_root=#{guest_root}

      rm -f $guest_root/boot/initrd* $guest_root/initrd*

      case "#{node[:rightimage][:platform]}" in
        "centos" )
          kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
    
          # Now rebuild ramdisk with xen drivers
          chroot $guest_root mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix \
             --with=ext3 -v initrd-#{node[:rightimage][:kernel_id]} #{node[:rightimage][:kernel_id]}
          mv $guest_root/initrd-$kernel_version  $guest_root/boot/.
          chroot $guest_root yum -y install grub
        ;;
        "ubuntu" )
          # These don't seem necessary.  Remove in the future?
          modules="mptbase mptscsih mptspi scsi_transport_spi apa_piix ext3"
          for mod in $modules
          do
            echo "$mod" >> $guest_root/etc/initramfs-tools/modules
          done 
          chroot $guest_root update-initramfs -c -k all
          chroot $guest_root apt-get -y install grub
        ;;
      esac
    EOH
  end
 
end
