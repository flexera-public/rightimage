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
# Load up prerequisites first
include_recipe "rightimage_tester"
include_recipe "loopback_fs"
include_recipe "rightscale::install_tools"
include_recipe "block_device"


class Chef::Recipe
  include RightScale::RightImage::Helper
end


# Requirement for nokogiri, which is a requirement for fog and rightimage_tools
packages = value_for_platform(
  "ubuntu" => {"default" => %w(libxml2-dev libxslt1-dev)},
  "default" => %w(libxml2-devel libxslt-devel)
)

packages.each do |p| 
  package p
end

# Install prereq so you don't auto-resolve to mime-types 2.0, which is ruby 1.9 only
gem_package "mime-types" do
  gem_binary "/usr/bin/gem"
  version "1.18.0"
  action :install
end

gem_package "fog" do
  gem_binary "/usr/bin/gem"
  version "1.5.0"
  action :install
end

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
  when "migrate"
    include_recipe "rightimage::ec2_download_bundle"
  end
end
rightscale_marker :end
