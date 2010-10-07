#
# Cookbook Name:: storage_test
# Recipe:: default
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

remote_storage "resource_one" do
  user "blah"
  key "blah"
  provider_type @node[:remote_storage][:provider_type] 
  action :nothing
end

remote_storage "resource_one" do
  container "MyBucket"
  object_name "file1.txt"
  action :get
end

remote_storage "resource_one" do
  object_name "file2.txt"
  action :get
end

