# Cookbook Name:: sysbench
# Recipe:: default
#
# Copyright 2012, RightScale, Inc.
#

package "sysbench"

node.set[:db][:admin][:user]     = "admin"
node.set[:db][:admin][:password] = node[:sysbench][:mysql_password]

node.set[:db][:application][:user]     = node[:sysbench][:mysql_user]
node.set[:db][:applicaiton][:password] = node[:sysbench][:mysql_password]

node.set[:db][:dns][:master][:fqdn] = "localhost"

include_recipe "rightscale::install_tools"

# Required by db_mysql but not explicitly required.  Normally installed
# as part of rightscale::install_tools at compile time so make sure this
# comes after
require 'system_timer'

include_recipe "db_mysql::setup_server_5_5"
include_recipe "db::install_server"
