#
# Cookbook Name:: remote_recipe
# Recipe:: default
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
log "============ remote_recipe_setup =============="

TAG = "test:ping=reciever"
log "Tag server as ping reciever. Tag: #{TAG}"

right_link_tag TAG




