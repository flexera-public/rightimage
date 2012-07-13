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


# Requirement for nokogiri and rightimage_tools now
packages = value_for_platform(
  "ubuntu" => {"default" => %w(libxml2-dev libxslt1-dev)},
  "default" => %w(libxml2-devel libxslt-devel)
)

packages.each do |p| 
  r = package p do 
    action :nothing 
  end
  r.run_action(:install)
end

SANDBOX_BIN_DIR = "/opt/rightscale/sandbox/bin"
# These are needed until rest_connection pins it's activesupport dependency version
r = gem_package "activesupport" do
  gem_binary "#{SANDBOX_BIN_DIR}/gem"
  version "2.3.10"
  action :nothing
end
r.run_action(:install)

r = gem_package "nokogiri" do 
  gem_binary "#{SANDBOX_BIN_DIR}/gem"
  version "1.5.4"
  action :nothing
end
r.run_action(:install)

r = gem_package "net-ssh" do 
  gem_binary "#{SANDBOX_BIN_DIR}/gem"
  version "2.1.4"
  action :nothing
end
r.run_action(:install)

RI_TOOL_VERSION = "0.2.2"
RI_TOOL_GEM = ::File.join(::File.dirname(__FILE__), "..", "files", "default", "rightimage_tools-#{RI_TOOL_VERSION}.gem")
r = gem_package RI_TOOL_GEM do
  gem_binary "#{SANDBOX_BIN_DIR}/gem"
  version RI_TOOL_VERSION
  action :nothing
end
r.run_action(:install)

Gem.clear_paths

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
