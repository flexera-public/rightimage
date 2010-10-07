#
# Cookbook Name:: rightlink_test
# Recipe:: remote_recipe_ping
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
log "============ remote_recipe_ping =============="

LOG_FILE = "/tmp/ping.log"

log "PING!"

# touch file
template LOG_FILE do
  source "pingpong.erb"
  variables( 
    :ping_type => "PING", 
    :from => @node[:remote_recipe][:from],
    :tags => @node[:remote_recipe][:tags] )
  action :create
end

output_file LOG_FILE

log "Requesting pong..."

# send pong to sender
remote_recipe "pong sender" do
  recipe "rightlink_test::resource_remote_recipe_pong"
  recipients @node[:remote_recipe][:from]
end
