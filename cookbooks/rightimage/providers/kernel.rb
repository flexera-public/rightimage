
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
      GUEST_ROOT=#{new_resource.guest_root}
      yum -c /tmp/yum.conf --installroot=$GUEST_ROOT -y install kernel-xen kmod-xfs-xen 
      chroot $GUEST_ROOT yum -y remove kernel
#      arch=#{node[:rightimage][:arch]}
#      [ $arch == "i386" ] && arch="i686"
#      rpm --root=$GUEST_ROOT --install http://elrepo.org/linux/kernel/el5/#{node[:rightimage][:arch]}/RPMS/kernel-ml-2.6.35-13.el5.elrepo.$arch.rpm

      kernel_version=$(ls -t $GUEST_ROOT/lib/modules|awk '{ printf "%s ", $0 }'|cut -d ' ' -f1-1)
 
      # Now rebuild ramdisk with xen drivers
      rm -f $GUEST_ROOT/boot/initrd*
      chroot $GUEST_ROOT mkinitrd --with=xennet --with=xenblk --with=ext3 --with=jbd --preload=xenblk initrd-$kernel_version $kernel_version
      mv $GUEST_ROOT/initrd-$kernel_version  $GUEST_ROOT/boot/.
    EOH
  end
  
end
