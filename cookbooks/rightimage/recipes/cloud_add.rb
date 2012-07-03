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

rightscale_marker :begin

class Chef::Resource
  include RightScale::RightImage::Helper
  alias :helper_image_name :image_name
end
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Erubis::Context
  include RightScale::RightImage::Helper
end

package "grub"

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

directory "#{guest_root}/etc/rightscale.d" do
  action :create
  recursive true
end

execute "echo -n #{node[:rightimage][:cloud]} > #{guest_root}/etc/rightscale.d/cloud" do 
  creates "#{guest_root}/etc/rightscale.d/cloud"
end

directory "#{guest_root}/var/spool/cloud" do
  action :create
  recursive true
end

log "Add RightLink 5.6 backwards compatibility symlink"
execute "chroot #{guest_root} ln -s /var/spool/cloud /var/spool/#{node[:rightimage][:cloud]}" do
  creates "#{guest_root}/var/spool/#{node[:rightimage][:cloud]}"
end

include_recipe "rightimage::enable_debug" if node[:rightimage][:debug] == "true"

# Bit of a cludge, needed for hypervisor installation,
template "/tmp/yum.conf" do 
  source "yum.conf.erb"
  only_if { el? }
  backup false
  variables ({
    :bootstrap => true
  })
end

# BEGIN cloud specific additions
rightimage_hypervisor node[:rightimage][:hypervisor] do
  platform          node[:rightimage][:platform]
  platform_version  node[:rightimage][:platform_version].to_f
  action :install_kernel
end

rightimage_hypervisor node[:rightimage][:hypervisor] do
  platform          node[:rightimage][:platform]
  platform_version  node[:rightimage][:platform_version].to_f
  action :install_tools
end

rightimage_cloud node[:rightimage][:cloud] do
  image_name  helper_image_name

  hypervisor        node[:rightimage][:hypervisor]
  arch              node[:rightimage][:arch]
  platform          node[:rightimage][:platform]
  platform_version  node[:rightimage][:platform_version].to_f

  action :configure
end
# END cloud specific additions

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

rightscale_marker :end
