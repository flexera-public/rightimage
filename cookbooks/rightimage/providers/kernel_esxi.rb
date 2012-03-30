class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install_kernel do
 
  bash "install esxi ramdisk" do
    flags "-ex"
    code <<-EOH
      # Install to guest. 
      guest_root=#{guest_root}

      rm -f $guest_root/boot/initrd* $guest_root/initrd*

      case "#{node[:rightimage][:platform]}" in
        "centos" )
          kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
    
          # Now rebuild ramdisk with xen drivers
          chroot $guest_root mkinitrd --with=mptbase --with=mptscsih --with=mptspi --with=scsi_transport_spi --with=ata_piix \
             --with=ext3 -v initrd-$kernel_version $kernel_version
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

action :install_tools do
  bash "install vmware tools" do
    flags "-ex"
    code <<-EOH
      guest_root=#{guest_root}
      TMP_DIR=/tmp/vmware_tools

  # TODO: THIS NEEDS TO BE CLEANED UP
    case "#{node[:rightimage][:platform]}" in 
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
     #  chroot $guest_root apt-get install -y --no-install-recommends open-vm-dkms
     #  chroot $guest_root apt-get install -y --no-install-recommends open-vm-tools 
      ;;

   esac
    EOH
  end
end

action :package_image do

  package "qemu"

  bash "cleanup working directories" do
    flags "-ex" 
    code <<-EOH
      rm -rf /tmp/ovftool.sh /tmp/ovftool #{target_temp_root}/temp.ovf #{target_temp_root}/#{image_name}*
    EOH
  end

  bundled_image = "#{image_name}.vmdk"
  bash "convert raw image to VMDK flat file" do
    cwd target_temp_root
    flags "-ex"
    code <<-EOH
      BUNDLED_IMAGE="#{bundled_image}"
      BUNDLED_IMAGE_PATH="#{target_temp_root}/$BUNDLED_IMAGE"

      qemu-img convert -O vmdk #{target_raw_path} $BUNDLED_IMAGE_PATH
    EOH
  end

  remote_file "/tmp/ovftool.sh" do
    source "VMware-ovftool-2.0.1-260188-lin.x86_64.sh"
    mode "0744"
  end

  bash "Install ovftools" do
    cwd "/tmp"
    flags "-ex"
    code <<-EOH
      mkdir -p /tmp/ovftool
      ./ovftool.sh --silent /tmp/ovftool AGREE_TO_EULA 
    EOH
  end

  ovf_filename = bundled_image
  ovf_image_name = bundled_image
  ovf_capacity = node[:rightimage][:root_size_gb] 
  ovf_ostype = "other26xLinux64Guest"

  template "#{target_temp_root}/temp.ovf" do
    source "ovf.erb"
    variables({
      :ovf_filename => ovf_filename,
      :ovf_image_name => ovf_image_name,
      :ovf_capacity => ovf_capacity,
      :ovf_ostype => ovf_ostype
    })
  end

  bash "Create create vmdk and create ovf/ova files" do
    cwd target_temp_root
    flags "-ex"
    code <<-EOH
      /tmp/ovftool/ovftool #{target_temp_root}/temp.ovf #{target_temp_root}/#{bundled_image}.ovf  > /dev/null 2>&1
      tar -cf #{bundled_image}.ova #{bundled_image}.ovf #{bundled_image}.mf #{image_name}.vmdk-disk*.vmdk
    EOH
  end
end
