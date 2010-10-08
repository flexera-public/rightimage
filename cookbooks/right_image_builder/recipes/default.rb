#
# Cookbook Name:: right_image_builder
# Recipe:: default
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "repo_git::default"

bash "add_gem_source" do
  code <<-EOC
    gem sources -a http://gems.rubyforge.org/
  EOC
end


[ "rspec", "flexmock", "event_machine", "resat", "json", "right_popen", "rest_connection", "gemedit", "ruby-debug", "fog", "trollop", "highline" ].each { |p| gem_package p }

repo "right_image_builder" do
  destination "/root/right_image_builder"
  action :pull
end

repo "image_sandbox" do
  destination "/root/sandbox_builds"
  action :pull
end

