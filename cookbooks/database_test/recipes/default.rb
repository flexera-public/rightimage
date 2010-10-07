#
# Cookbook Name:: database_test
# Recipe:: default
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

database "testdb" do
  action :lock
end

database "testdb" do
  action :lock
end

database "testdb" do
  action :unlock
end

database "testdb" do
  action :unlock
end
