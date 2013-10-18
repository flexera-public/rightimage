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
  bash "install vmware tools" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}
      TMP_DIR=/tmp/vmware_tools

  # TODO: THIS NEEDS TO BE CLEANED UP
    case "#{new_resource.platform}" in 
      "centos"|"rhel")
        chroot $guest_root mkdir -p $TMP_DIR
        chroot $guest_root curl --fail http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -o $TMP_DIR/dsa.pub
        chroot $guest_root curl --fail http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -o $TMP_DIR/rsa.pub
        chroot $guest_root rpm --import $TMP_DIR/dsa.pub
        chroot $guest_root rpm --import $TMP_DIR/rsa.pub
        cat > $guest_root/etc/yum.repos.d/vmware-tools.repo <<EOF
[vmware-tools]
name=VMware Tools
baseurl=http://packages.vmware.com/tools/esx/5.0/rhel5/x86_64
enabled=1
gpgcheck=1
EOF
     chroot $guest_root yum -y clean all
     chroot $guest_root yum -y install vmware-tools-esx-nox
     rm -f $guest_root/etc/yum.repos.d/vmware-tools.repo
      ;;

    "ubuntu" )
      # https://help.ubuntu.com/community/VMware/Tools#Installing VMware tools on an Ubuntu guest
      chroot $guest_root apt-get install -y --no-install-recommends open-vm-dkms
      chroot $guest_root apt-get install -y --no-install-recommends open-vm-tools
      ;;

   esac
    EOH
  end
end

