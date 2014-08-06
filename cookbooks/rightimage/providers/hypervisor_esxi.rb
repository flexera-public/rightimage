class Chef::Resource
  include RightScale::RightImage::Helper
end

action :install_kernel do
 
  bash "install esxi ramdisk" do
    flags "-ex"
    code <<-EOH
      # Install to guest. 
      guest_root=#{guest_root}

      case "#{new_resource.platform}" in
        "centos"|"rhel" )
          kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
    
          rm -f $guest_root/boot/initrd* $guest_root/initrd*

          # Now rebuild ramdisk with xen drivers
          chroot $guest_root mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix \
             --with=ext3 -v initrd-$kernel_version $kernel_version
          mv $guest_root/initrd-$kernel_version  $guest_root/boot/.
        ;;
        "ubuntu" )
        ;;
      esac
    EOH
  end
 
end

action :install_tools do
  cookbook_file "#{guest_root}/tmp/install_vmware_tools.sh" do
    backup false
    mode "0755"
    source "install_vmware_tools.sh"
  end

  cookbook_file "#{guest_root}/tmp/fake-uname" do
    source "fake-uname"
    mode "0777"
    backup false
  end

  cookbook_file "#{guest_root}/tmp/fake-vmware-checkvm" do
    source "fake-vmware-checkvm"
    mode "0777"
    backup false
  end

  bash "install vmware tools" do
    flags "-ex"
    environment(node[:rightimage][:script_env])
    code "chroot #{guest_root} /tmp/install_vmware_tools.sh"
  end

end

