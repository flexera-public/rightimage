rs_utils_marker :begin
class Chef::Resource::Bash
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end


raise "ERROR: you must set your virtual_environment to kvm!"  if node[:rightimage][:virtual_environment] != "kvm"

package "qemu"
package "grub"

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

bash "mount proc & dev" do 
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc || true
    umount -lf $guest_root/sys || true
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  action :install
end

# insert grub conf
template "#{guest_root}/boot/grub/menu.lst" do 
  source "menu.lst.erb"
  backup false 
end

bash "setup grub" do
  flags "-ex"
  code <<-EOH
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"
    
    chroot $guest_root mkdir -p /boot/grub

    case "#{node[:rightimage][:platform]}" in
      "ubuntu")
        chroot $guest_root cp -p /usr/lib/grub/x86_64-pc/* /boot/grub
        grub_command="/usr/sbin/grub"
        ;;
      "centos"|*)
        chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
        grub_command="/sbin/grub"
        ;;
    esac

    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $guest_root/boot/grub/device.map
    echo "" >> $guest_root/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF

  ${grub_command} --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 

  EOH
end

include_recipe "rightimage::bootstrap_common_debug"

bash "configure for cloudstack" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    # following found on functioning CDC test image Centos 64bit using KVM hypervisor
    echo "alias scsi_hostadapter ata_piix"     > $guest_root/etc/modprobe.conf
    echo "alias scsi_hostadapter1 virtio_blk" >> $guest_root/etc/modprobe.conf
    echo "alias eth0 virtio_net"              >> $guest_root/etc/modprobe.conf

    case "#{node[:rightimage][:platform]}" in
    "centos")
      # clean out packages
      chroot $guest_root yum -y clean all

      # clean centos RPM data
      rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb

      # enable console access
      echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
      echo "tty2" >> $guest_root/etc/securetty

      # configure dns timeout 
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf

      [ -f $guest_root/var/lib/rpm/__* ] && rm ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb
      ;;
    "ubuntu")
      # Disable all ttys except for tty1 (console)
      for i in `ls $guest_root/etc/init/tty[2-9].conf`; do
        mv $i $i.disabled;
      done
      ;;
    esac

    mkdir -p $guest_root/etc/rightscale.d
    echo "cloudstack" > $guest_root/etc/rightscale.d/cloud

    # set hwclock to UTC
    echo "UTC" >> $guest_root/etc/adjtime
  EOH
end

bash "unmount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc
    umount -lf $guest_root/dev
    umount -lf $guest_root/sys
  EOH
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

include_recipe "rightimage::do_destroy_loopback"

bash "backup raw image" do 
  cwd target_raw_root
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    target_temp_root=#{target_temp_root}
    cp -v $raw_image $target_temp_root
  EOH
end

bash "package image" do 
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    
    BUNDLED_IMAGE="#{image_name}.qcow2"
    BUNDLED_IMAGE_PATH="#{target_temp_root}/$BUNDLED_IMAGE"
    
    qemu-img convert -O qcow2 #{target_temp_path} $BUNDLED_IMAGE_PATH
    [ -f $BUNDLED_IMAGE_PATH.bz2 ] && rm -f $BUNDLED_IMAGE_PATH.bz2
    bzip2 $BUNDLED_IMAGE_PATH

  EOH
end
rs_utils_marker :end
