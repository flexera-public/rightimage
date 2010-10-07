#
# Cookbook Name:: resat
# Recipe:: default
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
base_dir = node[:test][:path][:src]

# Install packages for RESAT
package "ruby1.8-dev" 
package "rdoc" 
package "libmysql-ruby"

execute 'gem update --system'

# Install gem dependencies
[ "ruby-debug", "kwalify" ].each { |p| gem_package p }

# Install RESAT
gem_package "resat"

# Install test repo
repo_git_pull "Get test repo" do
  url "git@github.com:caryp/my_cookbooks.git"
  user git
  dest "#{base_dir}/tests"
  branch "db_mysql"
  cred node[:resat][:git_key]
end

# Create dummy output and input files for RESAT
file "#{base_dir}/variables.txt"
file "#{base_dir}/variables1.txt"

