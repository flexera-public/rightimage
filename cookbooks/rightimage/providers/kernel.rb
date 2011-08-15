
action :install do
 
#  bash "install ELrepo" do
#    code <<-EOH
#      rpm --import http://elrepo.org/RPM-GPG-KEY-elrepo.org
#    EOH
#  end

#  TMP_FILE = "/tmp/elrepo.rpm"

#  remote_file TMP_FILE do 
#    source "http://elrepo.org/elrepo-release-5-3.el5.elrepo.noarch.rpm"
#  end

#  package TMP_FILE do
#    source TMP_FILE
#  end

  bash "install xen kernel" do 
    only_if { new_resource.name == "xen" }
    code <<-EOH
      set -e 
      set -x
#      kernel_version=#{new_resource.version}
      
      # Install to guest. 
      guest_root=#{new_resource.guest_root}
      yum -c /tmp/yum.conf --installroot=$guest_root -y install kernel-xen kmod-xfs-xen 
      chroot $guest_root yum -y remove kernel
#      arch=#{node[:rightimage][:arch]}
#      [ $arch == "i386" ] && arch="i686"
#      rpm --root=$guest_root --install http://elrepo.org/linux/kernel/el5/#{node[:rightimage][:arch]}/RPMS/kernel-ml-2.6.35-13.el5.elrepo.$arch.rpm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
 
      # Now rebuild ramdisk with xen drivers
      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=xennet --with=xenblk --with=ext3 --with=jbd --preload=xenblk -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version  $guest_root/boot/.
    EOH
  end

 bash "install kvm kernel" do
  only_if { new_resource.name == "kvm" } 
  code <<-EOH
#!/bin/bash -ex
    set -e 
    set -x
    guest_root=#{new_resource.guest_root}


  case "#{node[:rightimage][:platform]}" in 
    "centos" )
      # The following should be needed when using ubuntu vmbuilder
      yum -c /tmp/yum.conf --installroot=$guest_root -y install kmod-kvm

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)

      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=ata_piix --with=virtio_blk --with=ext3 --with=virtio_pci --with=dm_mirror --with=dm_snapshot --with=dm_zero -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version $guest_root/boot/.
      ;;
    "ubuntu" )
      # Anything need to be done?
      ;;
  esac
      
  EOH
end

 
end
