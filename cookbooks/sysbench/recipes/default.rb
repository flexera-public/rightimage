# Cookbook Name:: sysbench
# Recipe:: default
#
# Copyright 2012, RightScale, Inc.
#

package "sysbench"

# Deploy MySQL database

# Setup password required by the mysql cookbook
node.set['mysql']['server_root_password']   = node[:sysbench][:mysql_password]
node.set['mysql']['server_repl_password']   = node[:sysbench][:mysql_password]
node.set['mysql']['server_debian_password'] = node[:sysbench][:mysql_password]

# User the root user
node.set['mysql']['allow_remote_root'] = false
node.set['mysql']['remove_anonymous_users'] = true

# Use the test database
node.set['mysql']['remove_test_database'] = false

include_recipe 'mysql::server'
