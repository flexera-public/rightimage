rs_utils_marker :begin
#
# Cookbook Name:: rightimage
# Recipe:: cloud_add_vmops
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
class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
end

log "Add DHCP symlink for RightLink"
execute "chroot #{guest_root} ln -s /var/lib/dhcp /var/lib/dhcp3" do
  only_if { File.exists?"#{guest_root}/var/lib/dhcp" }
  creates "#{guest_root}/var/lib/dhcp3"
end

include_recipe "rightimage::cloud_add_vmops_#{node[:rightimage][:virtual_environment]}" 
rs_utils_marker :end
