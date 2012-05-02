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

package "grub"

rightimage_cloud node[:rightimage][:cloud] do
  image_name  ::RightScale::RightImage::Helper.image_name

  hypervisor  node[:rightimage][:hypervisor]
  arch        node[:rightimage][:arch]
  platform    node[:rightimage][:platform]
  release     node[:rightimage][:release_number].to_f

  action :package
end

rs_utils_marker :end
