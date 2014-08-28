#
# Cookbook Name:: ros_upload
# Recipe:: default
#
# Copyright 2014, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

# Requirement for nokogiri, which is a requirement for fog and rightimage_tools

packages = 
  if platform_family?("debian")
    %w(libxml2-dev libxslt1-dev rubygems1.9.1 ruby1.9.1 ruby1.9.1-dev build-essential)
  else
    %w(libxml2-devel libxslt-devel rubygems ruby ruby-devel gcc-c++)
  end

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
  version "1.11.1"
  action :install
end
