#
# Cookbook Name:: rightlink_test
# Recipe:: state_test_check_value
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

log "============ state_test_check_value =============="

ruby_block "check value" do
  block do
    expected = "recipe"
    actual = node[:state_test][:value]
    Chef::Log.info "state_test::check_value -- Expected: #{expected} Actual: #{actual}"
    error = "ERROR: the node state is not persisted correctly between runs."
    raise error unless expected == actual 
    Chef::Log.info "state_test::check_value -- PASS"
  end
end
