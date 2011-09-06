class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end

action :install do
 
  bash "install xen kernel" do 
    code <<-EOH
      set -e 
      set -x
      
      # Install to guest. 
      guest_root=#{guest_root}
      yum -c /tmp/yum.conf --installroot=$guest_root -y install kernel-xen kmod-xfs-xen 
      chroot $guest_root yum -y remove kernel

      kernel_version=$(ls -t $guest_root/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
 
      # Now rebuild ramdisk with xen drivers
      rm -f $guest_root/boot/initrd* $guest_root/initrd*
      chroot $guest_root mkinitrd --with=xennet --with=xenblk --with=ext3 --with=jbd --preload=xenblk -v initrd-$kernel_version $kernel_version
      mv $guest_root/initrd-$kernel_version  $guest_root/boot/.
    EOH
  end
 
end
