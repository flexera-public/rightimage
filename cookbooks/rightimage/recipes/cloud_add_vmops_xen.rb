rs_utils_marker :begin
class Chef::Resource
  include RightScale::RightImage::Helper
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end

cloud = node[:rightimage][:cloud]
hypervisor = node[:rightimage][:virtual_environment]


raise "ERROR: you must set your cloud to vmops!"  if cloud != "vmops"
raise "ERROR: you must set your virtual_environment to xen!"  if hypervisor != "xen"

include_recipe "rightimage::install_vhd-util" if hypervisor == "xen"  

bash "create_vmops_image" do 
  flags "-ex"
  code <<-EOH
    guest_root="#{guest_root}"

    umount -lf #{guest_root}/proc || true 
    umount -lf #{guest_root}/sys || true 

    mkdir -p $guest_root/boot/grub
  EOH
end

log "  add fstab"
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

bash "mount proc" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    mount -t proc none $guest_root/proc
    mount --bind /dev $guest_root/dev
    mount --bind /sys $guest_root/sys
  EOH
end

log "  Install PV Kernel for Hypervisor"
rightimage_kernel "Install PV Kernel for Hypervisor" do
  provider "rightimage_kernel_#{hypervisor}"
  action :install
end

log "  insert grub conf"
template "#{guest_root}/boot/grub/grub.conf" do 
  source "menu.lst.erb"
  backup false 
end

log "  Link menu.list to our grub.conf"
file "#{guest_root}/boot/grub/menu.lst" do 
  action :delete
  backup false
end

link "#{guest_root}/boot/grub/menu.lst" do 
  to "#{guest_root}/boot/grub/grub.conf"
end

include_recipe "rightimage::bootstrap_common_debug"

bash "configure for cloudstack" do
  flags "-ex" 
  code <<-EOH
    guest_root=#{guest_root}

    case "#{node[:rightimage][:platform]}" in
    "centos" )
      # configure dns timeout 
      echo 'timeout 300;' > $guest_root/etc/dhclient.conf
      rm -f ${guest_root}/var/lib/rpm/__*
      chroot $guest_root rpm --rebuilddb
      ;;
    "ubuntu" )
      echo 'timeout 300;' > $guest_root/etc/dhcp3/dhclient.conf
      rm -f $guest_root/var/lib/dhcp3/*
      ;;  
    esac 

    # enable console access
    echo "2:2345:respawn:/sbin/mingetty xvc0" >> $guest_root/etc/inittab
    echo "xvc0" >> $guest_root/etc/securetty

    mkdir -p $guest_root/etc/rightscale.d
    echo "cloudstack" > $guest_root/etc/rightscale.d/cloud
  EOH
end

bash "unmount proc" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc || true
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

bash "xen convert" do 
  cwd target_temp_root
  flags "-ex"
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    vhd_image=${raw_image}.vhd
    vhd-util convert -s 0 -t 1 -i $raw_image -o $vhd_image
    vhd-util convert -s 1 -t 2 -i $vhd_image -o #{image_name}.vhd
    rm -f #{image_name}.vhd.bz2
    bzip2 #{image_name}.vhd
  EOH
end
rs_utils_marker :end
