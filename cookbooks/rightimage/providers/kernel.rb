
action :install do
  
  bash "install xen kernel" do 
    only_if { new_resource.name == "xen" }
    code <<-EOH
      set -e 
      set -x
      kernel_version=#{new_resource.version}
      
      # Install to guest. 
      # NOTE: for some reason kernel and modules are not being installed on 
      #       guest using --installroot option.
      GUEST_ROOT=#{new_resource.guest_root}
      rm -f $GUEST_ROOT/boot/vmlinu* 
      rm -rf $GUEST_ROOT/lib/modules/*
      yum -c /tmp/yum.conf --installroot=$GUEST_ROOT -y install kernel-xen
  
      # Also install to host so we can grab kernel and modules 
      # This is a workaround for the --installroot problem above (hacktastic, I know)
      yum -c /tmp/yum.conf -y install kernel-xen
      cp /boot/vmlinuz-$kernel_version $GUEST_ROOT/boot/
      cp -R /lib/modules/$kernel_version $GUEST_ROOT/lib/modules/$kernel_version
  
      # Now rebuild ramdisk with xen drivers
      rm -f $GUEST_ROOT/boot/initrd*
      chroot $GUEST_ROOT mkinitrd --with=xennet --with=xenblk --preload=xenblk initrd-$kernel_version $kernel_version
      mv $GUEST_ROOT/initrd-$kernel_version  $GUEST_ROOT/boot/.
    EOH
  end
  
end
