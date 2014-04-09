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

rightscale_marker :begin

class Chef::Recipe
  include RightScale::RightImage::Helper
end

# TODO: Move host package install here instead?
package "bzip2"
package "gcc"
#package "MAKEDEV" # only for Fedora?

# Load up prerequisites first
include_recipe "rightimage_tester"
include_recipe "loopback_fs"
include_recipe "ros_upload"

unless node[:rightimage][:manual_mode] == "true"
  case node[:rightimage][:build_mode] 
  when "full"
    if rebundle?
      include_recipe "rightimage::rebundle"
    else
      include_recipe "rightimage::build_image"
    end
  when "base"
    include_recipe "rightimage::build_base"
  end
end
rightscale_marker :end
