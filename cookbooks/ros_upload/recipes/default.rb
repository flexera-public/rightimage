#
# Cookbook Name:: ros_upload
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

# Requirement for nokogiri, which is a requirement for fog and rightimage_tools
packages = value_for_platform(
  "ubuntu" => {"default" => %w(libxml2-dev libxslt1-dev)},
  "default" => %w(libxml2-devel libxslt-devel)
)

packages.each do |p| 
  package p
end

gem_package "fog" do
  gem_binary "/usr/bin/gem"
  version "1.5.0"
  action :install
end