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

include_recipe "rightimage::enable_debug" if node[:rightimage][:debug] == "true"

rightimage_os node[:rightimage][:platform] do
  action :repo_freeze
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

execute "grub symlink" do
  only_if { ::File.exists?"#{guest_root}/boot/grub/menu.lst" }
  command "chroot #{guest_root} ln -s /boot/grub/menu.lst /boot/grub/grub.conf"
  creates "#{guest_root}/boot/grub/grub.conf"
end
# END cloud specific additions

rightimage_os node[:rightimage][:platform] do
  action :repo_unfreeze
end

bash "execute crontabs" do
  flags "-ex"
  code <<-EOF
    guest_root="#{guest_root}"
    # Pre-run all crontabs so future runs will be quicker (w-5672)
    # apt cron has a randomized sleep set, so to work around that we'll set RANDOM=0
    script=/tmp/prerun_cron.sh
    path=$guest_root/$script
    cat <<-CHROOT_SCRIPT > $path
cmd="cd / && RANDOM=0 run-parts";

for dir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
  echo "DIR: \\$dir";
  eval \\$cmd \\$dir;
done

# Kill anacron which gets started by cron.hourly.  This will kill anacron on
# the host too but since it doesn't use pid files, I don't see a better way.
killall --signal USR1 --wait anacron

# Delete rotated logs
find /var/log -name "*.[0-9]*" -exec rm -- {} \\;
CHROOT_SCRIPT

  chmod +x $path
  chroot $guest_root $script
  rm -f $path
  EOF
end

# Clean up guest image
rightimage guest_root do
  action :sanitize
end

directory "#{guest_root}#{node[:rightimage][:fstab][:ephemeral][:mount]}" do
  not_if { node[:rightimage][:fstab][:ephemeral][:dev] == nil }
  action :create
end

rightscale_marker :end
