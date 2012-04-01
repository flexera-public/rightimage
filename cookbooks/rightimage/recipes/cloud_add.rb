#
# Cookbook Name:: rightimage
# Recipe:: cloud_add
#
# Copyright 2011, RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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

package "grub"
package "qemu"

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

# add fstab
template "#{guest_root}/etc/fstab" do
  source "fstab.erb"
  backup false
end

# insert grub conf, and link menu.lst to grub.conf
directory "#{guest_root}/boot/grub" do
  owner "root"
  group "root"
  mode "0750"
  action :create
  recursive :true
end 

# Setup grub Version 1
template "#{guest_root}/boot/grub/grub.conf" do 
  not_if { node[:rightimage][:cloud] =~ /cloudstack|openstack/ } ### TBD, double check correct only if, see if we can delete this step
  source "menu.lst.erb"
  backup false 
end

file "#{guest_root}/boot/grub/menu.lst" do 
  not_if { node[:rightimage][:cloud] =~ /cloudstack|openstack/ } ### TBD, double check correct only if, see if we can delete this step
  action :delete
  backup false
end

link "#{guest_root}/boot/grub/menu.lst" do 
  not_if { node[:rightimage][:cloud] =~ /cloudstack|openstack/ } ### TBD, double check correct only if, see if we can delete this step
  to "#{guest_root}/boot/grub/grub.conf"
end

# Setup grub Version 2
bash "setup grub" do
  only_if { node[:rightimage][:cloud] =~ /cloudstack|openstack/ } ### TBD, double check correct only if, see if we can delete this step
  flags "-ex"
  code <<-EOH
    target_raw_path="#{target_raw_path}"
    guest_root="#{guest_root}"
    
    case "#{node[:rightimage][:platform]}" in
      "ubuntu")
        chroot $guest_root cp -p /usr/lib/grub/x86_64-pc/* /boot/grub
        grub_command="/usr/sbin/grub"
        ;;
      "centos"|"rhel")
        chroot $guest_root cp -p /usr/share/grub/x86_64-redhat/* /boot/grub
        grub_command="/sbin/grub"
        ;;
    esac

    chroot $guest_root ln -sf /boot/grub/grub.conf /boot/grub/menu.lst

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

directory "#{guest_root}/etc/rightscale.d" do
  action :create
  recursive true
end

execute "echo -n #{node[:rightimage][:cloud]} > #{guest_root}/etc/rightscale.d/cloud" do 
  creates "#{guest_root}/etc/rightscale.d/cloud"
end


include_recipe "rightimage::bootstrap_common_debug"


# BEGIN cloud specific additions
rightimage_hypervisor "Install PV kernel for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :install_kernel
end

rightimage_hypervisor "Install software toolchain for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :install_tools
end

rightimage_cloud "Configure for cloud #{node[:rightimage][:cloud]}" do
  provider "rightimage_cloud_#{node[:rightimage][:cloud]}"
  action :configure
end
# END cloud specific additions

 
bash "backup raw image" do 
  cwd target_raw_root
  code <<-EOH
    raw_image=$(basename #{target_raw_path})
    target_temp_root=#{target_temp_root}
    cp -v $raw_image $target_temp_root 
  EOH
end

rightimage_hypervisor "Package image for hypervisor" do
  provider "rightimage_hypervisor_#{node[:rightimage][:virtual_environment]}"
  action :package_image
end


bash "unmount proc & dev" do
  flags "-ex"
  code <<-EOH
    guest_root=#{guest_root}
    umount -lf $guest_root/proc || true
    umount -lf $guest_root/dev || true
    umount -lf $guest_root/sys || true
  EOH
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

bash "sync fs" do
  flags "-ex"
  code "sync"
end

rs_utils_marker :end
