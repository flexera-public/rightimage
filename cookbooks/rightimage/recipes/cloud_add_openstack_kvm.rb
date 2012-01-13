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

bash "mount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{node[:rightimage][:virtual_environment]}"
  action :install
end

bash "install grub" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    chroot $guest_root yum -y install grub
  EOH
end

# insert grub conf
template "#{guest_root}/boot/grub/grub.conf" do 
  source "menu.lst.erb"
  backup false 
end

bash "setup grub" do
  flags "-ex"
  code <<-EOH
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"
    
    chroot $guest_root mkdir -p /boot/grub
    chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
    chroot $guest_root ln -s /boot/grub/grub.conf /boot/grub/menu.lst
    
    echo "(hd0) #{node[:rightimage][:grub][:root_device]}" > $guest_root/boot/grub/device.map
    echo "" >> $guest_root/boot/grub/device.map

    cat > device.map <<EOF
(hd0) #{target_raw_path}
EOF
    /sbin/grub --batch --device-map=device.map <<EOF
root (hd0,0)
setup (hd0)
quit
EOF 
    
  EOH
end

include_recipe "rightimage::bootstrap_common_debug"

bash "configure for openstack" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}

    # clean out packages
    chroot $guest_root yum -y clean all

    # enable console access
    #echo "2:2345:respawn:/sbin/mingetty tty2" >> $guest_root/etc/inittab
    #echo "tty2" >> $guest_root/etc/securetty

    # configure dns timeout 
    echo 'timeout 300;' > $guest_root/etc/dhclient.conf

    mkdir -p $guest_root/etc/rightscale.d
    echo "openstack" > $guest_root/etc/rightscale.d/cloud

    rm ${guest_root}/var/lib/rpm/__*
    chroot $guest_root rpm --rebuilddb
    
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
  EOH
end
rs_utils_marker :end
