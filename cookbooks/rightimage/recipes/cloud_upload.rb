#
# Cookbook Name:: rightimage
# Recipe::upload_to_cloud
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

rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end
class Chef::Resource
  include RightScale::RightImage::Helper
  alias :helper_image_name :image_name
end

rightimage_cloud node[:rightimage][:cloud] do
  image_name  helper_image_name
  image_type  node[:rightimage][:ec2][:image_type]

  hypervisor  node[:rightimage][:hypervisor]
  arch        node[:rightimage][:arch]
  platform    node[:rightimage][:platform]
  platform_version node[:rightimage][:platform_version].to_f

  action :upload
end

# Only create reports for public cloud images if they are uploaded.
if node[:rightimage][:cloud] =~ /ec2|google|azure/
  include_recipe "rightimage::report_upload"
end

rightscale_marker :end
