rightscale_marker :begin
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
raise "ERROR: your build_mode input is set to #{node[:rightimage][:build_mode]}. Should be 'full'" unless node[:rightimage][:build_mode] == "full"

class Chef::Recipe
  include RightScale::RightImage::Helper
end

#directory temp_root do
#  owner "root"
#  group "root"
#  recursive true
#end

node[:rightimage][:host_packages].each { |p| package p.strip }

include_recipe "rightimage::loopback_download"
include_recipe "rightimage::loopback_resize"
include_recipe "rightimage::loopback_mount"
include_recipe "rightimage::clean"
include_recipe "rightimage::cloud_add"
include_recipe "rightimage::rightscale_install"
# Clean up guest image
rightimage guest_root do
  action :sanitize
end
include_recipe "rightimage::image_tests"
include_recipe "rightimage::loopback_unmount"
include_recipe "rightimage::cloud_package"
include_recipe "rightimage::upload_image_s3"
rightscale_marker :end
