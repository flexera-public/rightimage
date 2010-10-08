#
# Cookbook Name:: rest_connection
# Recipe:: default
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

["libxml2-dev", "libxml-ruby1.8", "libxslt1-dev", "libsqlite3-dev" ].each { |p| package p }

gem_package "activesupport" do
  version "2.3.5" 
end

gem_package "gemcutter" do
  version "0.5.0" 
end

["jeweler", "rdoc", "right_aws", "do_sqlite3", "dm-core", "ruby-debug", "rest_connection"].each { |p| gem_package p }


# Configure rest_connection
ssh_keys = Array.new
ssh_dir="/root/.ssh"
`echo "StrictHostKeyChecking no" >> #{ssh_dir}/config`
`echo "UserKnownHostsFile=/dev/null" >> #{ssh_dir}/config`
`rm -f #{ssh_dir}/known_hosts`

node[:rest_connection][:ssh][:key].keys.each do |kval|
  ssh_keys << kval
  `echo "#{node[:rest_connection][:ssh][:key][kval]}" > #{ssh_dir}/#{kval}`
  `chmod 600 #{ssh_dir}/#{kval}`
end

directory "#{node[:test][:path][:src]}/.rest_connection"

template "#{node[:test][:path][:src]}/.rest_connection/rest_api_config.yaml" do
  source "rest_api_config.yaml.erb"
  mode "600"
  variables({ :keys => ssh_keys })
end
