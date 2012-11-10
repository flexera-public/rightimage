rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: default
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


include_recipe "rightimage::clean"
include_recipe "rightimage::rightscale_install"

## Required for OS to automatically update grub.conf upon installation of new kernel (w-4950) ##
# Remove grub2 files
bash "remove_grub2" do
  flags "-x"
  code <<-EOH
    guest_root=#{guest_root}
    dpkg --root $guest_root --purge grub2-common grub-pc grub-pc-bin
    rm -rf $guest_root/boot/grub/menu.lst*
  EOH
end

# Adds hooks to run update-grub when adding/removing a kernel.
cookbook_file "#{guest_root}/etc/kernel-img.conf" do
  # Xen uses grub-legacy-ec2 which installs the appropriate hooks.
  not_if { node[:rightimage][:virtual_environment] == "xen" }
  source "kernel-img.conf"
  backup false
end
## END ##

rs_utils_marker :end
