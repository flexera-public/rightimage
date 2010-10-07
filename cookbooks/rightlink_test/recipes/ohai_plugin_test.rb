#
# Cookbook Name:: rightlink_test
# Recipe:: ohai_plugin_test
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

# Write values that our custom ohai plugins should provide
# This will fail if our plugins are not loaded
template "/tmp/ohai_values.log" do
  source "ohai_values.erb"
  action :create
end

output_file "/tmp/ohai_values.log"

# Check that chef is not using sandboxed ruby -- this is fixed by our custom ruby provider
ruby_block "ruby_bin should not point to sandbox" do
  block do
    test_failed = ( @node[:languages][:ruby][:ruby_bin] =~ /sandbox/ )
    raise "ERROR: ohai ruby plugin: 'ruby_bin' value points to sandbox: #{@node[:languages][:ruby][:ruby_bin]}" if test_failed
    Chef::Log.info("ruby_bin should not point to sandbox == PASS ==")
  end
end

# Check that chef is not using sandboxed gems -- this is fixed by our custom ruby provider
ruby_block "gems_dir should not point to sandbox" do
  block do
   test_failed = ( @node[:languages][:ruby][:gems_dir] =~ /sandbox/ )
   raise "ERROR: ohai ruby plugin: 'gems_dir' value points to sandbox: #{@node[:languages][:ruby][:gems_dir]}" if test_failed
   Chef::Log.info("gems_dir should not point to sandbox == PASS ==")
  end
end


