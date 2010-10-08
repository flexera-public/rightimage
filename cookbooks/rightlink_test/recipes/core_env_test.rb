#
# Cookbook Name:: core_env
# Recipe:: core_env_test
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

# Write RightScale injected values to a file
# This will fail if the core site is not injecting required values.
template "/tmp/core_env.log" do
  source "core_env.erb"
  action :create
end

output_file "/tmp/core_env.log"

