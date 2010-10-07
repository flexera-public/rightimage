#
# Cookbook Name:: rightlink_test
# Recipe:: persist_test_check
#
# Copyright 2010, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
if Chef::VERSION >= "0.8.16" && Chef::VERSION < "0.9"
  
  log "============ persist_test_check =============="
  
  # This should be run as an operational script
  # make sure you have rightlink_test::persist_test_setup in your boot scripts list
  
  log "  call create on persisted resource"
  # Call the create action on a resourse persisted to disk in the boot scripts 
  template "persist_test" do
    action :create
  end
  
  log "  output file created by persisted template"
  output_file node[:persist_test][:path]
  
else 
    log "======= Skipping persist_test_check for Chef v#{Chef::VERSION} ========="
end   