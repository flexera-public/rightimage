#
# Cookbook Name:: rightlink_test
# Recipe:: remote_recipe_pong
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
log "============ remote_recipe_pong =============="

LOGFILE = "/tmp/pong.log"

log "PONG!"

# touch file
template LOGFILE do
  backup 100
  source "pingpong.erb"
  variables( 
    :ping_type => "PONG", 
    :from => @node[:remote_recipe][:from],
    :tags => @node[:remote_recipe][:tags] )
  action :create
end

output_file LOGFILE


