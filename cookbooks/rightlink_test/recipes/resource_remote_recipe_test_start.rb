#
# Cookbook Name:: remote_recipe
# Recipe:: default
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#

log "============ resource test: remote_recipe =============="

log "send ping to receiver"

remote_recipe "ping receiver" do
  recipe "rightlink_test::resource_remote_recipe_ping"
  recipients_tags "test:ping=reciever"
end

