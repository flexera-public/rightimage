#
# Cookbook Name:: rightlink_test
# Recipe:: state_test_setup
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

log "============ state_test_setup =============="

FILENAME = "state_test.txt"
TEST_DIR = ::File.join(::File::SEPARATOR, "var", "cache", "rightscale", "test")
TEST_FILE = ::File.join(TEST_DIR, FILENAME)

ruby_block "set value" do
  not_if do ::File.exists?(TEST_FILE) end
  block do
    Chef::Log.info "Explicitly setting value to: recipe"
    node[:state_test][:value] = "recipe"
  end
end

# Write file to flag if this has been run before
directory TEST_DIR do
  recursive true
end

template TEST_FILE do
  source "#{FILENAME}.erb"
  action :create
end

output_file TEST_FILE
