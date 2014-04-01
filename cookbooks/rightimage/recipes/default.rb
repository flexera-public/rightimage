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

# Requirement for nokogiri, which is a requirement for fog and rightimage_tools
packages = value_for_platform(
  "ubuntu" => {"default" => %w(libxml2-dev libxslt1-dev ruby-dev)},
  "default" => %w(libxml2-devel libxslt-devel ruby-devel)
)

packages.each do |p| 
  package p
end

# TODO: Move host package install here instead?
package "bzip2"
package "gcc"
#package "MAKEDEV" # only for Fedora?

# Since we're using /usr/bin/gem below, we need to make sure it is installed
# first, also before other include_recipes that are using /usr/bin/gem
package "rubygems" do
  # Hack for rbenv. You may not need the package installed.
  not_if "which gem"
end

# Dependency of fog, v2 requires Ruby 1.9.2+
gem_package "mime-types" do
  version "< 2.0"
  action :install
end

gem_package "fog" do
  version "1.5.0"
  action :install
end

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
